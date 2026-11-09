import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

class CloudSyncService {
  CloudSyncService._();

  static final instance = CloudSyncService._();

  static const _tables = [
    'debts',
    'orders',
    'shifts',
    'expenses',
    'other_incomes',
    'debt_payments',
    'wallet_transactions',
    'calendar_notes',
    'calendar_events',
    'app_settings',
    'order_payouts',
  ];
  Future<void>? _activeSync;

  Future<void> sync(String userId) {
    final activeSync = _activeSync;
    if (activeSync != null) {
      return activeSync.then((_) => sync(userId));
    }
    final operation = _sync(userId);
    _activeSync = operation;
    return operation.whenComplete(() => _activeSync = null);
  }

  Future<void> _sync(String userId) async {
    final db = await AppDatabase.instance.database;
    final syncOwners = await db.query('sync_owner', where: 'id = 1');
    if (syncOwners.isNotEmpty && syncOwners.single['user_id'] != userId) {
      throw StateError(
        'Este dispositivo ya está vinculado a otra cuenta de Google. '
        'Para proteger tus datos, solo se permite una cuenta sincronizada '
        'por instalación.',
      );
    }
    if (syncOwners.isEmpty) {
      await db.insert('sync_owner', {'id': 1, 'user_id': userId});
    }
    final records = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('records');
    final deviceId = await _deviceId(db);
    final remoteSnapshot = await records.get();
    final remote = {
      for (final document in remoteSnapshot.docs) document.id: document.data(),
    };
    final metadataRows = await db.query(
      'sync_metadata',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    final metadata = {
      for (final row in metadataRows)
        '${row['table_name']}:${row['local_key']}': row,
    };
    final pendingWrites = <_PendingWrite>[];

    final localRows = <String, List<Map<String, Object?>>>{};
    for (final table in _tables) {
      localRows[table] = (await db.query(table))
          .map((row) => Map<String, Object?>.from(row))
          .toList();
    }

    final debtRemoteByLocalId = <int, String>{};
    final debtLocalByRemoteId = <String, int>{};
    for (final row in localRows['debts']!) {
      final localKey = '${row['id']}';
      final state = metadata['debts:$localKey'];
      final remoteId =
          state?['remote_id'] as String? ??
          _newRemoteId(deviceId, 'debts', localKey);
      debtRemoteByLocalId[row['id'] as int] = remoteId;
      debtLocalByRemoteId[remoteId] = row['id'] as int;
    }

    for (final table in _tables) {
      final rows = localRows[table]!;
      final seenLocalKeys = <String>{};

      for (final row in rows) {
        final localKey = _localKey(table, row);
        seenLocalKeys.add(localKey);
        final metadataKey = '$table:$localKey';
        final state = metadata[metadataKey];
        final remoteId =
            state?['remote_id'] as String? ??
            _remoteId(table, row, deviceId, debtRemoteByLocalId);
        final cloudData = _toCloudData(table, row, debtRemoteByLocalId);
        final baseline = state?['baseline_json'] as String?;
        final localJson = _canonicalJson(cloudData);
        final localChanged = baseline == null || baseline != localJson;
        final remoteRecord = remote[remoteId];

        if (remoteRecord == null) {
          pendingWrites.add(
            _PendingWrite(
              remoteId: remoteId,
              table: table,
              data: cloudData,
              updatedAt: DateTime.now().millisecondsSinceEpoch,
              deleted: false,
              localKey: localKey,
              baselineJson: localJson,
            ),
          );
          continue;
        }

        final remoteDeleted = remoteRecord['deleted'] == true;
        final remoteData = Map<String, Object?>.from(
          (remoteRecord['data'] as Map?)?.cast<String, Object?>() ?? const {},
        );
        final remoteJson = _canonicalJson(remoteData);
        final remoteChanged =
            remoteDeleted || baseline == null || baseline != remoteJson;
        final localUpdatedAt = localChanged
            ? DateTime.now().millisecondsSinceEpoch
            : state?['updated_at'] as int? ?? 0;
        final remoteUpdatedAt = remoteRecord['updated_at'] as int? ?? 0;

        if (remoteChanged &&
            (state == null ||
                !localChanged ||
                remoteUpdatedAt > localUpdatedAt)) {
          if (remoteDeleted) {
            await _deleteLocalRecord(db, table, localKey, row);
            await _saveMetadata(
              db,
              userId,
              table,
              localKey,
              remoteId,
              baselineJson: remoteJson,
              updatedAt: remoteUpdatedAt,
              deleted: true,
            );
          } else {
            final updatedLocalKey = await _applyRemoteRecord(
              db,
              table,
              localKey,
              remoteData,
              debtLocalByRemoteId,
            );
            await _saveMetadata(
              db,
              userId,
              table,
              updatedLocalKey,
              remoteId,
              baselineJson: remoteJson,
              updatedAt: remoteUpdatedAt,
              deleted: false,
            );
            if (table == 'debts') {
              final id = int.parse(updatedLocalKey);
              debtLocalByRemoteId[remoteId] = id;
              debtRemoteByLocalId[id] = remoteId;
            }
          }
        } else if (localChanged) {
          final updatedAt = DateTime.now().millisecondsSinceEpoch;
          pendingWrites.add(
            _PendingWrite(
              remoteId: remoteId,
              table: table,
              data: cloudData,
              updatedAt: updatedAt,
              deleted: false,
              localKey: localKey,
              baselineJson: localJson,
            ),
          );
        }
      }

      for (final state in metadataRows.where(
        (row) => row['table_name'] == table,
      )) {
        final localKey = state['local_key'] as String;
        if (seenLocalKeys.contains(localKey) || state['deleted'] == 1) {
          continue;
        }
        final remoteId = state['remote_id'] as String;
        final remoteRecord = remote[remoteId];
        if (remoteRecord?['deleted'] == true) {
          continue;
        }
        final updatedAt = DateTime.now().millisecondsSinceEpoch;
        pendingWrites.add(
          _PendingWrite(
            remoteId: remoteId,
            table: table,
            data: const {},
            updatedAt: updatedAt,
            deleted: true,
            localKey: localKey,
            baselineJson: '{}',
          ),
        );
      }

      for (final entry in remote.entries.where(
        (entry) => entry.value['table'] == table,
      )) {
        final state = metadataRows.where(
          (row) => row['table_name'] == table && row['remote_id'] == entry.key,
        );
        if (state.isNotEmpty) continue;
        final remoteRecord = entry.value;
        final data = Map<String, Object?>.from(
          (remoteRecord['data'] as Map?)?.cast<String, Object?>() ?? const {},
        );
        if (remoteRecord['deleted'] == true) {
          await _saveMetadata(
            db,
            userId,
            table,
            'remote:${entry.key}',
            entry.key,
            baselineJson: _canonicalJson(data),
            updatedAt: remoteRecord['updated_at'] as int? ?? 0,
            deleted: true,
          );
          continue;
        }
        final localKey = await _applyRemoteRecord(
          db,
          table,
          null,
          data,
          debtLocalByRemoteId,
        );
        await _saveMetadata(
          db,
          userId,
          table,
          localKey,
          entry.key,
          baselineJson: _canonicalJson(data),
          updatedAt: remoteRecord['updated_at'] as int? ?? 0,
          deleted: false,
        );
        if (table == 'debts') {
          final id = int.parse(localKey);
          debtLocalByRemoteId[entry.key] = id;
          debtRemoteByLocalId[id] = entry.key;
        }
      }
    }

    for (var start = 0; start < pendingWrites.length; start += 450) {
      final batch = FirebaseFirestore.instance.batch();
      final end = min(start + 450, pendingWrites.length);
      for (final write in pendingWrites.sublist(start, end)) {
        batch.set(records.doc(write.remoteId), {
          'table': write.table,
          'data': write.data,
          'updated_at': write.updatedAt,
          'deleted': write.deleted,
        });
      }
      await batch.commit();
      for (final write in pendingWrites.sublist(start, end)) {
        await _saveMetadata(
          db,
          userId,
          write.table,
          write.localKey,
          write.remoteId,
          baselineJson: write.baselineJson,
          updatedAt: write.updatedAt,
          deleted: write.deleted,
        );
      }
    }
  }

  Future<String> _deviceId(Database db) async {
    final rows = await db.query('sync_device', where: 'id = 1');
    if (rows.isNotEmpty) return rows.single['device_id'] as String;
    final id = _randomId();
    await db.insert('sync_device', {'id': 1, 'device_id': id});
    return id;
  }

  String _newRemoteId(String deviceId, String table, String localKey) =>
      '$deviceId:$table:$localKey';

  String _remoteId(
    String table,
    Map<String, Object?> row,
    String deviceId,
    Map<int, String> debtRemoteByLocalId,
  ) {
    if (table == 'shifts') return 'shift:${row['day']}';
    if (table == 'app_settings') return 'settings:1';
    if (table == 'order_payouts') {
      return 'order_payout:${row['cycle_due_day']}';
    }
    if (table == 'debt_payments') {
      final debtId = row['debt_id'] as int;
      final debtRemoteId =
          debtRemoteByLocalId[debtId] ??
          _newRemoteId(deviceId, 'debts', '$debtId');
      return 'debt_payment:$debtRemoteId:${row['month']}';
    }
    if (table == 'wallet_transactions' && row['kind'] == 'debt_payment') {
      final parsed = _parseDebtSourceKey(row['source_key'] as String);
      if (parsed != null) {
        final debtRemoteId =
            debtRemoteByLocalId[parsed.$1] ??
            _newRemoteId(deviceId, 'debts', '${parsed.$1}');
        return 'wallet_debt:$debtRemoteId:${parsed.$2}';
      }
    }
    return _newRemoteId(deviceId, table, _localKey(table, row));
  }

  String _localKey(String table, Map<String, Object?> row) {
    switch (table) {
      case 'shifts':
        return 'day:${row['day']}';
      case 'debt_payments':
        return '${row['debt_id']}:${row['month']}';
      case 'app_settings':
        return '1';
      case 'order_payouts':
        return '${row['cycle_due_day']}';
      default:
        if (table == 'wallet_transactions' && row['kind'] == 'debt_payment') {
          return 'source:${row['source_key']}';
        }
        return '${row['id']}';
    }
  }

  Map<String, Object?> _toCloudData(
    String table,
    Map<String, Object?> row,
    Map<int, String> debtRemoteByLocalId,
  ) {
    if (table == 'app_settings') {
      return {
        'dark_mode': row['dark_mode'],
        'accent_color': row['accent_color'],
        'withholding_percent': row['withholding_percent'],
        'first_payout_day': row['first_payout_day'],
        'second_payout_day': row['second_payout_day'],
        'card_billing_day': row['card_billing_day'],
      };
    }
    final data = Map<String, Object?>.from(row)..remove('id');
    if (table == 'debts') data['legacy_payment_id'] = null;
    if (table == 'debt_payments') {
      final debtId = data.remove('debt_id') as int;
      data['debt_remote_id'] = debtRemoteByLocalId[debtId];
    } else if (table == 'wallet_transactions' &&
        data['kind'] == 'debt_payment') {
      final parsed = _parseDebtSourceKey(data['source_key'] as String);
      if (parsed != null) {
        data['source_key'] =
            'debt:${debtRemoteByLocalId[parsed.$1]}:${parsed.$2}';
      }
    }
    return data;
  }

  Future<String> _applyRemoteRecord(
    Database db,
    String table,
    String? currentLocalKey,
    Map<String, Object?> remoteData,
    Map<String, int> debtLocalByRemoteId,
  ) async {
    if (table == 'app_settings') {
      final localRows = await db.query(
        'app_settings',
        where: 'id = 1',
        limit: 1,
      );
      final local = localRows.single;
      final settings = <String, Object?>{};
      for (final column in [
        'dark_mode',
        'accent_color',
        'withholding_percent',
        'first_payout_day',
        'second_payout_day',
        'card_billing_day',
      ]) {
        settings[column] = remoteData[column] ?? local[column];
      }
      await db.update('app_settings', settings, where: 'id = 1');
      return '1';
    }
    final data = Map<String, Object?>.from(remoteData);
    if (table == 'debt_payments') {
      final remoteDebtId = data.remove('debt_remote_id') as String;
      final debtId = debtLocalByRemoteId[remoteDebtId];
      if (debtId == null) {
        throw StateError('No se encontró la deuda vinculada al pago.');
      }
      data['debt_id'] = debtId;
    } else if (table == 'wallet_transactions' &&
        data['kind'] == 'debt_payment') {
      final parsed = _parseCloudDebtSourceKey(data['source_key'] as String);
      if (parsed != null) {
        final debtId = debtLocalByRemoteId[parsed.$1];
        if (debtId == null) {
          throw StateError('No se encontró la deuda del movimiento.');
        }
        data['source_key'] = 'debt:$debtId:${parsed.$2}';
      }
    }

    final where = _whereFor(table, currentLocalKey, data);
    final existing = await db.query(
      table,
      where: where.$1,
      whereArgs: where.$2,
      limit: 1,
    );
    if (existing.isNotEmpty) {
      if (table == 'order_payouts') {
        await db.update(
          table,
          data,
          where: 'cycle_due_day = ?',
          whereArgs: [data['cycle_due_day']],
        );
        return '${data['cycle_due_day']}';
      }
      final id = existing.single['id'];
      if (table == 'debt_payments') {
        await db.update(
          table,
          data,
          where: 'debt_id = ? AND month = ?',
          whereArgs: [data['debt_id'], data['month']],
        );
        return '${data['debt_id']}:${data['month']}';
      }
      if (table == 'shifts') {
        await db.update(table, data, where: 'id = ?', whereArgs: [id]);
        return 'day:${data['day']}';
      }
      await db.update(table, data, where: 'id = ?', whereArgs: [id]);
      if (table == 'wallet_transactions' && data['kind'] == 'debt_payment') {
        return 'source:${data['source_key']}';
      }
      return '$id';
    }
    final insertedId = await db.insert(
      table,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (table == 'order_payouts') return '${data['cycle_due_day']}';
    if (table == 'debt_payments') {
      return '${data['debt_id']}:${data['month']}';
    }
    if (table == 'shifts') return 'day:${data['day']}';
    if (table == 'wallet_transactions' && data['kind'] == 'debt_payment') {
      return 'source:${data['source_key']}';
    }
    return '$insertedId';
  }

  (String, List<Object?>) _whereFor(
    String table,
    String? localKey,
    Map<String, Object?> data,
  ) {
    if (table == 'order_payouts') {
      return ('cycle_due_day = ?', [data['cycle_due_day']]);
    }
    if (table == 'debt_payments') {
      return ('debt_id = ? AND month = ?', [data['debt_id'], data['month']]);
    }
    if (table == 'shifts') return ('day = ?', [data['day']]);
    if (table == 'wallet_transactions' && data['kind'] == 'debt_payment') {
      return ('source_key = ?', [data['source_key']]);
    }
    if (localKey != null && int.tryParse(localKey) != null) {
      return ('id = ?', [int.parse(localKey)]);
    }
    return ('id = ?', [-1]);
  }

  Future<void> _deleteLocalRecord(
    Database db,
    String table,
    String localKey,
    Map<String, Object?> row,
  ) async {
    if (table == 'app_settings') return;
    if (table == 'order_payouts') {
      await db.delete(
        table,
        where: 'cycle_due_day = ?',
        whereArgs: [row['cycle_due_day']],
      );
      return;
    }
    if (table == 'debt_payments') {
      await db.delete(
        table,
        where: 'debt_id = ? AND month = ?',
        whereArgs: [row['debt_id'], row['month']],
      );
      return;
    }
    if (table == 'shifts') {
      await db.delete(table, where: 'day = ?', whereArgs: [row['day']]);
      return;
    }
    if (table == 'wallet_transactions' && row['kind'] == 'debt_payment') {
      await db.delete(
        table,
        where: 'source_key = ?',
        whereArgs: [row['source_key']],
      );
      return;
    }
    await db.delete(table, where: 'id = ?', whereArgs: [row['id']]);
  }

  Future<void> _saveMetadata(
    Database db,
    String userId,
    String table,
    String localKey,
    String remoteId, {
    required String baselineJson,
    required int updatedAt,
    required bool deleted,
  }) async {
    await db.insert('sync_metadata', {
      'user_id': userId,
      'table_name': table,
      'local_key': localKey,
      'remote_id': remoteId,
      'baseline_json': baselineJson,
      'updated_at': updatedAt,
      'deleted': deleted ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  (int, String)? _parseDebtSourceKey(String value) {
    final parts = value.split(':');
    if (parts.length != 3 || parts.first != 'debt') return null;
    final debtId = int.tryParse(parts[1]);
    return debtId == null ? null : (debtId, parts[2]);
  }

  (String, String)? _parseCloudDebtSourceKey(String value) {
    final parts = value.split(':');
    if (parts.length != 3 || parts.first != 'debt') return null;
    return (parts[1], parts[2]);
  }

  String _canonicalJson(Map<String, Object?> data) {
    final sorted = Map<String, Object?>.fromEntries(
      data.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    return jsonEncode(sorted);
  }

  String _randomId() {
    final random = Random.secure();
    return '${DateTime.now().microsecondsSinceEpoch}-'
        '${random.nextInt(1 << 32)}';
  }
}

class _PendingWrite {
  const _PendingWrite({
    required this.remoteId,
    required this.table,
    required this.data,
    required this.updatedAt,
    required this.deleted,
    required this.localKey,
    required this.baselineJson,
  });

  final String remoteId;
  final String table;
  final Map<String, Object?> data;
  final int updatedAt;
  final bool deleted;
  final String localKey;
  final String baselineJson;
}
