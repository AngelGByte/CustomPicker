import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _database;
  Future<Database>? _openingDatabase;

  Future<Database> get database async {
    final openedDatabase = _database;
    if (openedDatabase != null) return openedDatabase;
    try {
      return await (_openingDatabase ??= _openDatabase());
    } catch (_) {
      _openingDatabase = null;
      rethrow;
    }
  }

  Future<Database> _openDatabase() async {
    final dbPath = path.join(await getDatabasesPath(), 'picker_control.db');
    final db = await openDatabase(
      dbPath,
      version: 10,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT NOT NULL,
            day TEXT NOT NULL,
            sku_count INTEGER NOT NULL,
            bonus INTEGER NOT NULL,
            notes TEXT NOT NULL,
            base_rate INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE shifts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            day TEXT NOT NULL UNIQUE,
            start_time TEXT NOT NULL,
            end_time TEXT NOT NULL,
            bonus INTEGER NOT NULL,
            notes TEXT NOT NULL
          )
        ''');
        await _createFinanceTables(db);
        await _createWalletTables(db);
        await db.execute('''
          CREATE TABLE calendar_notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            day TEXT NOT NULL,
            title TEXT NOT NULL,
            notes TEXT NOT NULL
          )
        ''');
        await _createCalendarEventsTable(db);
        await db.execute('CREATE INDEX orders_day_idx ON orders(day)');
        await db.execute('CREATE INDEX notes_day_idx ON calendar_notes(day)');
        await db.execute(
          'CREATE INDEX calendar_events_day_idx ON calendar_events(day)',
        );
        await _createAppSettingsTable(db);
        await _createSyncTables(db);
        await _createOrderPayoutsTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createFinanceTables(db);
          await db.execute('''
            INSERT INTO debts (
              title, notes, type, amount, start_day, installment_count,
              end_month, legacy_payment_id
            )
            SELECT title, notes, 'installments', amount, day, 1, NULL, id
            FROM payments
            WHERE kind = 'payable'
          ''');
          await db.execute('''
            INSERT INTO debt_payments (debt_id, month, is_paid, paid_amount)
            SELECT debts.id, substr(debts.start_day, 1, 7), payments.is_paid,
              CASE WHEN payments.is_paid = 1 THEN payments.amount ELSE 0 END
            FROM debts
            JOIN payments ON payments.id = debts.legacy_payment_id
          ''');
          await _createWalletTables(db);
          await db.execute('''
            INSERT INTO wallet_transactions (kind, source_key, day, amount)
            SELECT 'debt_payment',
              'debt:' || debts.id || ':' || substr(debts.start_day, 1, 7),
              debts.start_day, payments.amount
            FROM debts
            JOIN payments ON payments.id = debts.legacy_payment_id
            WHERE payments.is_paid = 1
          ''');
        } else if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE debt_payments ADD COLUMN paid_amount INTEGER NOT NULL DEFAULT 0',
          );
          await _createWalletTables(db);
          await _migrateExistingDebtPayments(db);
        }
        if (oldVersion < 4) {
          await _createAppSettingsTable(db);
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE orders_new (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              code TEXT NOT NULL,
              day TEXT NOT NULL,
              sku_count INTEGER NOT NULL,
              bonus INTEGER NOT NULL,
              notes TEXT NOT NULL,
              base_rate INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            INSERT INTO orders_new (id, code, day, sku_count, bonus, notes, base_rate)
            SELECT id, code, day, sku_count, bonus, notes, base_rate FROM orders
          ''');
          await db.execute('DROP TABLE orders');
          await db.execute('ALTER TABLE orders_new RENAME TO orders');
          await db.execute('CREATE INDEX orders_day_idx ON orders(day)');
        }
        if (oldVersion < 6) {
          final settingsColumns = await db.rawQuery(
            'PRAGMA table_info(app_settings)',
          );
          if (!settingsColumns.any(
            (column) => column['name'] == 'withholding_percent',
          )) {
            await db.execute(
              'ALTER TABLE app_settings ADD COLUMN withholding_percent REAL NOT NULL DEFAULT 15.25',
            );
          }
          await _createCalendarEventsTable(db);
          await db.execute(
            'CREATE INDEX calendar_events_day_idx ON calendar_events(day)',
          );
        }
        if (oldVersion < 7) {
          await _createSyncTables(db);
        }
        if (oldVersion < 8) {
          final expenseColumns = await db.rawQuery(
            'PRAGMA table_info(expenses)',
          );
          if (!expenseColumns.any(
            (column) => column['name'] == 'payment_method',
          )) {
            await db.execute(
              "ALTER TABLE expenses ADD COLUMN payment_method TEXT NOT NULL DEFAULT 'debit'",
            );
          }
          if (!expenseColumns.any(
            (column) => column['name'] == 'card_billed',
          )) {
            await db.execute(
              'ALTER TABLE expenses ADD COLUMN card_billed INTEGER NOT NULL DEFAULT 0',
            );
          }
          final debtPaymentColumns = await db.rawQuery(
            'PRAGMA table_info(debt_payments)',
          );
          if (!debtPaymentColumns.any(
            (column) => column['name'] == 'due_day',
          )) {
            await db.execute('ALTER TABLE debt_payments ADD COLUMN due_day TEXT');
          }
          final settingsColumns = await db.rawQuery(
            'PRAGMA table_info(app_settings)',
          );
          if (!settingsColumns.any(
            (column) => column['name'] == 'first_payout_day',
          )) {
            await db.execute(
              'ALTER TABLE app_settings ADD COLUMN first_payout_day INTEGER NOT NULL DEFAULT 6',
            );
          }
          if (!settingsColumns.any(
            (column) => column['name'] == 'second_payout_day',
          )) {
            await db.execute(
              'ALTER TABLE app_settings ADD COLUMN second_payout_day INTEGER NOT NULL DEFAULT 21',
            );
          }
          if (!settingsColumns.any(
            (column) => column['name'] == 'card_billing_day',
          )) {
            await db.execute(
              'ALTER TABLE app_settings ADD COLUMN card_billing_day INTEGER NOT NULL DEFAULT 5',
            );
          }
          if (!settingsColumns.any(
            (column) => column['name'] == 'profile_name',
          )) {
            await db.execute('ALTER TABLE app_settings ADD COLUMN profile_name TEXT');
          }
          await _createOrderPayoutsTable(db);
          await _migrateHistoricalOrderPayouts(db);
        }
        if (oldVersion < 9) {
          final expenseColumns = await db.rawQuery(
            'PRAGMA table_info(expenses)',
          );
          if (!expenseColumns.any(
            (column) => column['name'] == 'card_billed_month',
          )) {
            await db.execute(
              'ALTER TABLE expenses ADD COLUMN card_billed_month TEXT',
            );
          }
          await _migrateBilledCardExpenses(db);
        }
        if (oldVersion < 10) {
          final eventColumns = await db.rawQuery(
            'PRAGMA table_info(calendar_events)',
          );
          if (!eventColumns.any(
            (column) => column['name'] == 'reminder_minutes',
          )) {
            await db.execute(
              'ALTER TABLE calendar_events ADD COLUMN reminder_minutes INTEGER NOT NULL DEFAULT 0',
            );
          }
        }
      },
    );
    _database = db;
    return db;
  }

  Future<void> _createSyncTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_device (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        device_id TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_owner (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        user_id TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_metadata (
        user_id TEXT NOT NULL,
        table_name TEXT NOT NULL,
        local_key TEXT NOT NULL,
        remote_id TEXT NOT NULL,
        baseline_json TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (user_id, table_name, local_key)
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS sync_metadata_remote_idx '
      'ON sync_metadata(user_id, table_name, remote_id)',
    );
  }

  Future<void> _createAppSettingsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        dark_mode INTEGER NOT NULL,
        accent_color INTEGER NOT NULL,
        withholding_percent REAL NOT NULL DEFAULT 15.25,
        first_payout_day INTEGER NOT NULL DEFAULT 6,
        second_payout_day INTEGER NOT NULL DEFAULT 21,
        card_billing_day INTEGER NOT NULL DEFAULT 5,
        profile_name TEXT
      )
    ''');
    await db.insert('app_settings', {
      'id': 1,
      'dark_mode': 0,
      'accent_color': AppThemeSettings.defaults.accentColor,
      'withholding_percent': AppThemeSettings.defaults.withholdingPercent,
      'first_payout_day': AppThemeSettings.defaults.firstPayoutDay,
      'second_payout_day': AppThemeSettings.defaults.secondPayoutDay,
      'card_billing_day': AppThemeSettings.defaults.cardBillingDay,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<AppThemeSettings> getAppSettings() async {
    final rows = await (await database).query(
      'app_settings',
      where: 'id = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return AppThemeSettings.defaults;
    return AppThemeSettings(
      darkMode: rows.first['dark_mode'] == 1,
      accentColor: rows.first['accent_color'] as int,
      withholdingPercent: (rows.first['withholding_percent'] as num).toDouble(),
      firstPayoutDay: rows.first['first_payout_day'] as int,
      secondPayoutDay: rows.first['second_payout_day'] as int,
      cardBillingDay: rows.first['card_billing_day'] as int,
    );
  }

  Future<void> saveAppSettings(AppThemeSettings settings) async {
    final db = await database;
    await db.update(
      'app_settings',
      {
        'dark_mode': settings.darkMode ? 1 : 0,
        'accent_color': settings.accentColor,
        'withholding_percent': settings.withholdingPercent,
        'first_payout_day': settings.firstPayoutDay,
        'second_payout_day': settings.secondPayoutDay,
        'card_billing_day': settings.cardBillingDay,
      },
      where: 'id = 1',
    );
  }

  Future<String?> getProfileName() async {
    final rows = await (await database).query(
      'app_settings',
      columns: ['profile_name'],
      where: 'id = 1',
    );
    return rows.isEmpty ? null : rows.first['profile_name'] as String?;
  }

  Future<void> saveProfileName(String name) async {
    await (await database).update(
      'app_settings',
      {'profile_name': name.trim()},
      where: 'id = 1',
    );
  }

  Future<void> _createOrderPayoutsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS order_payouts (
        cycle_due_day TEXT PRIMARY KEY,
        gross_amount INTEGER NOT NULL,
        net_amount INTEGER NOT NULL,
        received_day TEXT NOT NULL
      )
    ''');
  }

  Future<void> _migrateHistoricalOrderPayouts(DatabaseExecutor db) async {
    final settingsRows = await db.query(
      'app_settings',
      columns: ['withholding_percent'],
      where: 'id = 1',
    );
    final withholding = settingsRows.isEmpty
        ? defaultSiiWithholdingPercent
        : (settingsRows.single['withholding_percent'] as num).toDouble();
    final today = dayKey(DateTime.now());
    final grossByDueDay = <String, int>{};
    final orders = await db.query('orders');
    for (final row in orders) {
      final order = PickerOrder.fromMap(row);
      final dueDay = orderPayoutDueDay(
        order.day,
        firstPayoutDay: 6,
        secondPayoutDay: 21,
      );
      if (dueDay.compareTo(today) >= 0) continue;
      grossByDueDay.update(
        dueDay,
        (gross) => gross + order.total,
        ifAbsent: () => order.total,
      );
    }
    final shifts = await db.query('shifts');
    for (final row in shifts) {
      final shift = WorkShift.fromMap(row);
      final dueDay = orderPayoutDueDay(
        shift.day,
        firstPayoutDay: 6,
        secondPayoutDay: 21,
      );
      if (dueDay.compareTo(today) >= 0) continue;
      grossByDueDay.update(
        dueDay,
        (gross) => gross + shift.bonus,
        ifAbsent: () => shift.bonus,
      );
    }
    for (final entry in grossByDueDay.entries) {
      await db.insert('order_payouts', {
        'cycle_due_day': entry.key,
        'gross_amount': entry.value,
        'net_amount': calculateNetAfterSii(entry.value, withholding),
        'received_day': entry.key,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _migrateBilledCardExpenses(DatabaseExecutor db) async {
    final settings = await db.query(
      'app_settings',
      columns: ['card_billing_day'],
      where: 'id = 1',
      limit: 1,
    );
    final billingDay = settings.isEmpty
        ? AppThemeSettings.defaults.cardBillingDay
        : settings.single['card_billing_day'] as int;
    final billedRows = await db.query(
      'expenses',
      where: "payment_method = 'credit' AND card_billed = 1",
    );
    for (final row in billedRows) {
      final cycle = cardExpenseBillingMonth(
        day: row['day'] as String,
        billingDay: billingDay,
      );
      final cycleMonth =
          '${(cycle ~/ 100).toString().padLeft(4, '0')}-'
          '${(cycle % 100).toString().padLeft(2, '0')}';
      await db.update(
        'expenses',
        {'card_billed_month': cycleMonth},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }

    await db.delete('wallet_transactions', where: "kind = 'card_billing'");
    for (final row in billedRows) {
      final cycle = cardExpenseBillingMonth(
        day: row['day'] as String,
        billingDay: billingDay,
      );
      final dueDay = dayKey(DateTime(cycle ~/ 100, cycle % 100, billingDay));
      await db.insert('wallet_transactions', {
        'kind': 'card_billing',
        'source_key': 'card_expense:${row['id']}',
        'day': dueDay,
        'amount': row['amount'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> _createCalendarEventsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS calendar_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        day TEXT NOT NULL,
        start_time TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        notify INTEGER NOT NULL,
        reminder_minutes INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _createFinanceTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        title TEXT NOT NULL,
        day TEXT NOT NULL,
        amount INTEGER NOT NULL,
        notes TEXT NOT NULL,
        payment_method TEXT NOT NULL DEFAULT 'debit',
        card_billed INTEGER NOT NULL DEFAULT 0,
        card_billed_month TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE debts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        notes TEXT NOT NULL,
        type TEXT NOT NULL,
        amount INTEGER NOT NULL,
        start_day TEXT NOT NULL,
        installment_count INTEGER,
        end_month TEXT,
        legacy_payment_id INTEGER UNIQUE
      )
    ''');
    await db.execute('''
      CREATE TABLE debt_payments (
        debt_id INTEGER NOT NULL,
        month TEXT NOT NULL,
        is_paid INTEGER NOT NULL,
        paid_amount INTEGER NOT NULL DEFAULT 0,
        due_day TEXT,
        PRIMARY KEY (debt_id, month),
        FOREIGN KEY (debt_id) REFERENCES debts(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX expenses_day_idx ON expenses(day)');
  }

  Future<void> _createWalletTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS other_incomes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source TEXT NOT NULL,
        day TEXT NOT NULL,
        amount INTEGER NOT NULL,
        notes TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS wallet_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kind TEXT NOT NULL,
        source_key TEXT NOT NULL UNIQUE,
        day TEXT NOT NULL,
        amount INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS other_incomes_day_idx ON other_incomes(day)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS wallet_transactions_day_idx ON wallet_transactions(day)',
    );
  }

  Future<void> _migrateExistingDebtPayments(DatabaseExecutor db) async {
    final rows = await db.rawQuery('''
      SELECT debt_payments.debt_id, debt_payments.month, debts.type,
        debts.amount, debts.start_day, debts.installment_count
      FROM debt_payments
      JOIN debts ON debts.id = debt_payments.debt_id
      WHERE debt_payments.is_paid = 1
    ''');
    for (final row in rows) {
      final debtId = row['debt_id'] as int;
      final month = row['month'] as String;
      final type = DebtType.values.byName(row['type'] as String);
      final totalAmount = row['amount'] as int;
      final startDay = row['start_day'] as String;
      final startMonth = monthKey(DateTime.parse(startDay));
      final installmentIndex = monthsBetween(startMonth, month);
      final installmentCount = row['installment_count'] as int?;
      if (installmentIndex < 0 ||
          (type == DebtType.installments &&
              (installmentCount == null ||
                  installmentIndex >= installmentCount))) {
        continue;
      }

      final paidAmount = type == DebtType.monthly
          ? totalAmount
          : installmentAmountForMonth(
              totalAmount: totalAmount,
              installmentCount: installmentCount!,
              installmentNumber: installmentIndex + 1,
            );
      final date = DateTime.parse(startDay);
      final dueMonth = DateTime.parse('$month-01');
      final daysInMonth = DateTime(dueMonth.year, dueMonth.month + 1, 0).day;
      final paymentDay = dayKey(
        DateTime(dueMonth.year, dueMonth.month, date.day.clamp(1, daysInMonth)),
      );
      await db.update(
        'debt_payments',
        {'paid_amount': paidAmount},
        where: 'debt_id = ? AND month = ?',
        whereArgs: [debtId, month],
      );
      await db.insert('wallet_transactions', {
        'kind': 'debt_payment',
        'source_key': 'debt:$debtId:$month',
        'day': paymentDay,
        'amount': paidAmount,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<List<PickerOrder>> getOrders() async {
    final rows = await (await database).query(
      'orders',
      orderBy: 'day DESC, id DESC',
    );
    return rows.map(PickerOrder.fromMap).toList();
  }

  Future<void> saveOrder(PickerOrder order) async {
    final db = await database;
    if (order.id == null) {
      await db.insert('orders', order.toMap()..remove('id'));
    } else {
      await db.update(
        'orders',
        order.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [order.id],
      );
    }
  }

  Future<void> deleteOrder(int id) async {
    await (await database).delete('orders', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<WorkShift>> getShifts() async {
    final rows = await (await database).query('shifts', orderBy: 'day DESC');
    return rows.map(WorkShift.fromMap).toList();
  }

  Future<void> saveShift(WorkShift shift) async {
    final db = await database;
    if (shift.id == null) {
      await db.insert('shifts', shift.toMap()..remove('id'));
    } else {
      await db.update(
        'shifts',
        shift.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [shift.id],
      );
    }
  }

  Future<void> deleteShift(int id) async {
    await (await database).delete('shifts', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ExpenseEntry>> getExpenses() async {
    final rows = await (await database).query(
      'expenses',
      orderBy: 'day DESC, id DESC',
    );
    return rows.map(ExpenseEntry.fromMap).toList();
  }

  Future<void> saveExpense(ExpenseEntry expense) async {
    final db = await database;
    if (expense.id == null) {
      await db.insert('expenses', expense.toMap()..remove('id'));
      return;
    }

    final oldRows = await db.query(
      'expenses',
      columns: ['card_billed_month'],
      where: 'id = ?',
      whereArgs: [expense.id],
      limit: 1,
    );
    final billedMonth =
        expense.cardBilledMonth ??
        (oldRows.isEmpty ? null : oldRows.single['card_billed_month'] as String?);
    final data = expense.toMap()
      ..remove('id')
      ..['card_billed_month'] = billedMonth
      ..['card_billed'] = billedMonth == null ? 0 : 1;
    await db.update(
      'expenses',
      data,
      where: 'id = ?',
      whereArgs: [expense.id],
    );
    final transactionKey = 'card_expense:${expense.id}';
    if (billedMonth != null &&
        expense.paymentMethod == ExpensePaymentMethod.credit) {
      final settings = await db.query(
        'app_settings',
        columns: ['card_billing_day'],
        where: 'id = 1',
        limit: 1,
      );
      final billingDay = settings.single['card_billing_day'] as int;
      final month = DateTime.parse('$billedMonth-01');
      await db.insert('wallet_transactions', {
        'kind': 'card_billing',
        'source_key': transactionKey,
        'day': dayKey(DateTime(month.year, month.month, billingDay)),
        'amount': expense.amount,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await db.delete(
        'wallet_transactions',
        where: 'source_key = ?',
        whereArgs: [transactionKey],
      );
    }
  }

  Future<void> deleteExpense(int id) async {
    final db = await database;
    await db.transaction((transaction) async {
      await transaction.delete(
        'wallet_transactions',
        where: 'source_key = ?',
        whereArgs: ['card_expense:$id'],
      );
      await transaction.delete('expenses', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<DebtEntry>> getDebts() async {
    final rows = await (await database).query(
      'debts',
      orderBy: 'start_day DESC, id DESC',
    );
    return rows.map(DebtEntry.fromMap).toList();
  }

  Future<void> saveDebt(DebtEntry debt) async {
    final db = await database;
    if (debt.id == null) {
      await db.insert('debts', debt.toMap()..remove('id'));
    } else {
      await db.update(
        'debts',
        debt.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [debt.id],
      );
    }
  }

  Future<void> deleteDebt(int id) async {
    final db = await database;
    await db.delete('debt_payments', where: 'debt_id = ?', whereArgs: [id]);
    await db.delete('debts', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, int>> getDebtPaymentAmounts() async {
    final rows = await (await database).query('debt_payments');
    return {
      for (final row in rows)
        if (row['is_paid'] == 1)
          '${row['debt_id']}:${row['month']}': row['paid_amount'] as int,
    };
  }

  Future<Map<String, String>> getDebtDueDays() async {
    final rows = await (await database).query(
      'debt_payments',
      where: 'due_day IS NOT NULL',
    );
    return {
      for (final row in rows)
        '${row['debt_id']}:${row['month']}': row['due_day'] as String,
    };
  }

  Future<int> getTotalDebtPayments() async {
    final rows = await (await database).rawQuery(
      "SELECT COALESCE(SUM(amount), 0) AS total FROM wallet_transactions WHERE kind IN ('debt_payment', 'card_billing')",
    );
    return rows.single['total'] as int;
  }

  Future<int> getCurrentWalletBalance() async {
    final rows = await (await database).rawQuery('''
      SELECT
        (SELECT COALESCE(SUM(net_amount), 0) FROM order_payouts) +
        (SELECT COALESCE(SUM(amount), 0) FROM other_incomes) -
        (SELECT COALESCE(SUM(amount), 0) FROM expenses
          WHERE payment_method = 'debit') -
        (SELECT COALESCE(SUM(amount), 0) FROM wallet_transactions
          WHERE kind IN ('debt_payment', 'card_billing')) AS balance
    ''');
    return rows.single['balance'] as int;
  }

  Future<List<OrderPayout>> getOrderPayouts() async {
    final rows = await (await database).query(
      'order_payouts',
      orderBy: 'cycle_due_day DESC',
    );
    return rows.map(OrderPayout.fromMap).toList();
  }

  Future<void> recordOrderPayout(OrderPayout payout) async {
    await (await database).insert(
      'order_payouts',
      payout.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> billCardCycle({
    required String month,
    required int billingDay,
  }) async {
    final db = await database;
    final debtRows = await db.query('debts');
    final debts = debtRows.map(DebtEntry.fromMap).toList();
    final paymentRows = await db.query('debt_payments');
    final paidAmounts = {
      for (final row in paymentRows)
        if (row['is_paid'] == 1)
          '${row['debt_id']}:${row['month']}': row['paid_amount'] as int,
    };
    final dueDays = {
      for (final row in paymentRows)
        if (row['due_day'] != null)
          '${row['debt_id']}:${row['month']}': row['due_day'] as String,
    };
    final monthDate = DateTime.parse('$month-01');
    final cardOccurrences = debtOccurrencesForMonth(
      debts.where((debt) => debt.type == DebtType.installments).toList(),
      monthDate,
      paidAmountsByStatusKey: paidAmounts,
      dueDaysByStatusKey: dueDays,
    ).where((occurrence) => !occurrence.isPaid).toList();
    final expenseRows = await db.query(
      'expenses',
      where: "payment_method = 'credit' AND card_billed_month IS NULL",
    );
    final cycleExpenses = expenseRows
        .where(
          (row) =>
              cardExpenseBillingMonth(
                day: row['day'] as String,
                billingDay: billingDay,
              ) ==
              monthDate.year * 100 + monthDate.month,
        )
        .toList();
    final expenseTotal = cycleExpenses.fold<int>(
      0,
      (total, row) => total + (row['amount'] as int),
    );
    final installmentTotal = cardOccurrences.fold<int>(
      0,
      (total, occurrence) => total + occurrence.amount,
    );
    final total = expenseTotal + installmentTotal;
    if (total <= 0) return 0;

    await db.transaction((transaction) async {
      for (final row in cycleExpenses) {
        await transaction.update(
          'expenses',
          {'card_billed': 1, 'card_billed_month': month},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
      for (final occurrence in cardOccurrences) {
        final debtId = occurrence.debt.id!;
        await transaction.insert('debt_payments', {
          'debt_id': debtId,
          'month': month,
          'is_paid': 1,
          'paid_amount': occurrence.amount,
          'due_day': occurrence.dueDay,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await transaction.insert('wallet_transactions', {
          'kind': 'debt_payment',
          'source_key': 'debt:$debtId:$month',
          'day': dayKey(DateTime(monthDate.year, monthDate.month, billingDay)),
          'amount': occurrence.amount,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final row in cycleExpenses) {
        await transaction.insert('wallet_transactions', {
          'kind': 'card_billing',
          'source_key': 'card_expense:${row['id']}',
          'day': dayKey(DateTime(monthDate.year, monthDate.month, billingDay)),
          'amount': row['amount'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    return total;
  }

  Future<void> setDebtPaid({
    required int debtId,
    required String month,
    required bool isPaid,
    required String day,
    required int amount,
  }) async {
    final db = await database;
    final sourceKey = 'debt:$debtId:$month';
    await db.transaction((transaction) async {
      if (isPaid) {
        await transaction.insert('debt_payments', {
          'debt_id': debtId,
          'month': month,
          'is_paid': 1,
          'paid_amount': amount,
          'due_day': day,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await transaction.insert('wallet_transactions', {
          'kind': 'debt_payment',
          'source_key': sourceKey,
          'day': day,
          'amount': amount,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } else {
        await transaction.update(
          'debt_payments',
          {'is_paid': 0, 'paid_amount': 0},
          where: 'debt_id = ? AND month = ?',
          whereArgs: [debtId, month],
        );
        await transaction.delete(
          'wallet_transactions',
          where: 'source_key = ?',
          whereArgs: [sourceKey],
        );
      }
    });
  }

  Future<void> setDebtDueDay({
    required int debtId,
    required String month,
    required String dueDay,
  }) async {
    final db = await database;
    final updated = await db.update(
      'debt_payments',
      {'due_day': dueDay},
      where: 'debt_id = ? AND month = ?',
      whereArgs: [debtId, month],
    );
    if (updated == 0) {
      await db.insert('debt_payments', {
        'debt_id': debtId,
        'month': month,
        'is_paid': 0,
        'paid_amount': 0,
        'due_day': dueDay,
      });
    }
  }

  Future<List<OtherIncomeEntry>> getOtherIncomes() async {
    final rows = await (await database).query(
      'other_incomes',
      orderBy: 'day DESC, id DESC',
    );
    return rows.map(OtherIncomeEntry.fromMap).toList();
  }

  Future<void> saveOtherIncome(OtherIncomeEntry income) async {
    final db = await database;
    if (income.id == null) {
      await db.insert('other_incomes', income.toMap()..remove('id'));
    } else {
      await db.update(
        'other_incomes',
        income.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [income.id],
      );
    }
  }

  Future<void> deleteOtherIncome(int id) async {
    await (await database).delete(
      'other_incomes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<CalendarNote>> getNotes() async {
    final rows = await (await database).query(
      'calendar_notes',
      orderBy: 'day DESC, id DESC',
    );
    return rows.map(CalendarNote.fromMap).toList();
  }

  Future<void> saveNote(CalendarNote note) async {
    final db = await database;
    if (note.id == null) {
      await db.insert('calendar_notes', note.toMap()..remove('id'));
    } else {
      await db.update(
        'calendar_notes',
        note.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [note.id],
      );
    }
  }

  Future<void> deleteNote(int id) async {
    await (await database).delete(
      'calendar_notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<CalendarEvent>> getCalendarEvents() async {
    final rows = await (await database).query(
      'calendar_events',
      orderBy: 'day DESC, start_time DESC, id DESC',
    );
    return rows.map(CalendarEvent.fromMap).toList();
  }

  Future<CalendarEvent> saveCalendarEvent(CalendarEvent event) async {
    final db = await database;
    if (event.id == null) {
      final id = await db.insert(
        'calendar_events',
        event.toMap()..remove('id'),
      );
      return event.copyWith(id: id);
    }
    await db.update(
      'calendar_events',
      event.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [event.id],
    );
    return event;
  }

  Future<void> deleteCalendarEvent(int id) async {
    await (await database).delete(
      'calendar_events',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
