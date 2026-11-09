import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import 'formatters.dart';
import 'models.dart';

class CalendarHomeWidget {
  CalendarHomeWidget._();

  static const appGroupId = 'group.com.mypocket.app';
  static const kind = 'MyPocketCalendarWidget';
  static const androidProvider = 'com.mypocket.app.CalendarHomeWidgetProvider';

  static Future<void> configure() async {
    final configured = await HomeWidget.setAppGroupId(appGroupId);
    if (configured == false) {
      throw StateError('No se pudo configurar el grupo compartido del widget.');
    }
  }

  static Future<void> update(List<CalendarEvent> events) async {
    final now = DateTime.now();
    final upcoming = events
        .where((event) => event.startsAt.isAfter(now))
        .toList()
      ..sort((first, second) => first.startsAt.compareTo(second.startsAt));

    final entries = upcoming.take(20).map((event) {
      final eventDate = DateTime.parse(event.day);
      final today = DateUtils.dateOnly(now);
      final date = DateUtils.dateOnly(eventDate);
      final dayLabel = date == today
          ? 'Hoy'
          : date == today.add(const Duration(days: 1))
          ? 'Mañana'
          : capitalize(formatShortDay(event.day));
      return {
        'title': event.title,
        'day': dayLabel,
        'time': event.startTime,
        'timestamp': event.startsAt.millisecondsSinceEpoch,
      };
    }).toList();

    final saved = await HomeWidget.saveWidgetData<String>(
      'agendaEvents',
      jsonEncode(entries),
    );
    if (saved == false) {
      throw StateError('No se pudieron guardar los eventos para el widget.');
    }

    await HomeWidget.updateWidget(
      name: kind,
      androidName: androidProvider,
      iOSName: kind,
    );
  }
}
