import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import 'models.dart';

class EventNotificationService {
  EventNotificationService._();

  static final instance = EventNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  Future<void>? _initializing;

  Future<void> _initialize() async {
    try {
      await (_initializing ??= _initializePlugin());
    } catch (_) {
      _initializing = null;
      rethrow;
    }
  }

  Future<void> _initializePlugin() async {
    timezone_data.initializeTimeZones();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    timezone.setLocalLocation(timezone.getLocation(localTimezone.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  Future<bool> scheduleEvent(CalendarEvent event) async {
    final id = event.id;
    if (id == null) {
      throw ArgumentError.value(event.id, 'event.id', 'Must be saved first.');
    }

    await _initialize();
    await _plugin.cancel(id: id);
    if (!event.notify) return true;
    if (!event.startsAt.isAfter(DateTime.now())) return false;
    final notificationAt = event.notificationAt.isAfter(DateTime.now())
        ? event.notificationAt
        : DateTime.now().add(const Duration(seconds: 1));

    final granted = await _requestPermission();
    if (!granted) return false;

    await _plugin.zonedSchedule(
      id: id,
      title: event.title,
      body: _notificationBody(event),
      scheduledDate: timezone.TZDateTime.from(notificationAt, timezone.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'calendar_events',
          'Eventos del calendario',
          channelDescription: 'Avisos de tus eventos y sesiones',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    return true;
  }

  String _notificationBody(CalendarEvent event) {
    final description = event.description.isEmpty
        ? ''
        : '${event.description} · ';
    if (event.reminderMinutes == 0) {
      return '${description}Tu evento comienza ahora.';
    }
    return '${description}Tu evento comienza en '
        '${_reminderLabel(event.reminderMinutes)}.';
  }

  String _reminderLabel(int minutes) {
    if (minutes == 1440) return '1 día';
    if (minutes == 60) return '1 hora';
    return '$minutes minutos';
  }

  Future<bool> _requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final iOS = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await iOS?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
  }

  Future<void> cancelEvent(int id) async {
    await _initialize();
    await _plugin.cancel(id: id);
  }
}
