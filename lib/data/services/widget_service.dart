import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/prayer_day.dart';

class WidgetService {
  static Future<void> savePrayerSchedule(
    List<PrayerDay> days, {
    String timezone = '',
  }) async {
    try {
      final points = <Map<String, dynamic>>[];

      for (final day in days) {
        final date = DateTime.tryParse(day.date);
        if (date == null) continue;

        final prayers = <String, String>{
          'Fajr': day.fajr,
          'Sunrise': day.sunrise,
          'Dhuhr': day.dhuhr,
          'Asr': day.asr,
          'Maghrib': day.maghrib,
          'Isha': day.isha,
        };

        for (final entry in prayers.entries) {
          final at = _parsePrayerTime(
            date,
            entry.value,
            entry.key,
            timezone: timezone,
          );
          if (at == null) continue;
          points.add({
            'name': entry.key,
            'at': at.millisecondsSinceEpoch,
          });
        }
      }

      points.sort((a, b) => (a['at'] as int).compareTo(b['at'] as int));
      await HomeWidget.saveWidgetData<String>(
        'prayer_schedule_json',
        jsonEncode(points),
      );
      await HomeWidget.saveWidgetData<String>('widget_timezone', timezone);
    } catch (e) {
      debugPrint('Error saving widget prayer schedule: $e');
    }
  }

  static Future<void> savePreferences({
    required String languageCode,
    required bool use24HourFormat,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('widget_language', languageCode);
      await HomeWidget.saveWidgetData<bool>('widget_use_24h', use24HourFormat);
    } catch (e) {
      debugPrint('Error saving widget preferences: $e');
    }
  }

  static DateTime? _parsePrayerTime(
    DateTime date,
    String raw,
    String prayerName, {
    required String timezone,
  }) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw.trim());
    if (match == null) return null;

    var hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');
    if (hour == null || minute == null || minute > 59) return null;

    if (['Asr', 'Maghrib', 'Isha'].contains(prayerName) && hour < 12) {
      hour += 12;
    }
    if (prayerName == 'Dhuhr' && hour < 10) {
      hour += 12;
    }
    if (hour > 23) return null;

    if (timezone.trim().isNotEmpty) {
      try {
        final location = tz.getLocation(timezone);
        return tz.TZDateTime(
          location,
          date.year,
          date.month,
          date.day,
          hour,
          minute,
        );
      } catch (_) {}
    }

    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  static Future<void> updateWidget({
    required String currentTime,
    required String nextPrayer,
    required String timeLeft,
    required DateTime? nextPrayerTime,
    required String languageCode,
    required bool use24HourFormat,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('current_time', currentTime);
      await HomeWidget.saveWidgetData<String>('next_prayer', nextPrayer);
      await HomeWidget.saveWidgetData<String>('time_left', timeLeft);
      await HomeWidget.saveWidgetData<String>('widget_language', languageCode);
      await HomeWidget.saveWidgetData<bool>('widget_use_24h', use24HourFormat);
      await HomeWidget.saveWidgetData<int>(
        'next_prayer_epoch_ms',
        nextPrayerTime?.millisecondsSinceEpoch ?? 0,
      );
      await HomeWidget.saveWidgetData<int>(
        'next_prayer_at',
        nextPrayerTime?.millisecondsSinceEpoch ?? 0,
      );

      await HomeWidget.updateWidget(
        name: 'PrayerWidgetSmall',
        androidName: 'PrayerWidgetSmall',
      );
      await HomeWidget.updateWidget(
        name: 'PrayerWidgetMedium',
        androidName: 'PrayerWidgetMedium',
      );
      await HomeWidget.updateWidget(
        name: 'PrayerWidgetLarge',
        androidName: 'PrayerWidgetLarge',
      );
    } catch (e) {
      debugPrint('Error updating widgets: $e');
    }
  }
}
