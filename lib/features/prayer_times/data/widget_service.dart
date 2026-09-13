import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:timezone/timezone.dart' as tz;

import 'models/prayer_day.dart';

class WidgetService {
  static const iOSAppGroupId = 'group.com.abdalmqadma.munib';
  static const _iOSWidgetName = 'PrayerWidget';

  static const _androidWidgetNames = <String>[
    'PrayerWidgetSmall',
    'PrayerWidgetMedium',
    'PrayerWidgetLarge',
    'PrayerLockWidget',
  ];

  static Future<void> savePrayerSchedule(
    List<PrayerDay> days, {
    String timezone = '',
  }) async {
    try {
      await _preparePlatform();
      final points = <Map<String, dynamic>>[];

      for (final day in days) {
        final date = DateTime.tryParse(day.date);
        if (date == null) continue;

        final prayers = <String, String>{
          'Fajr': day.fajr,
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
      await _refreshAll();
    } catch (e) {
      debugPrint('Error saving widget prayer schedule: $e');
    }
  }

  static Future<void> savePreferences({
    required String languageCode,
    required bool use24HourFormat,
  }) async {
    try {
      await _preparePlatform();
      await HomeWidget.saveWidgetData<String>('widget_language', languageCode);
      await HomeWidget.saveWidgetData<bool>('widget_use_24h', use24HourFormat);
      await _refreshAll();
    } catch (e) {
      debugPrint('Error saving widget preferences: $e');
    }
  }

  static Future<void> saveThemePreference(String preference) async {
    try {
      await _preparePlatform();
      final normalized = switch (preference) {
        'light' => 'light',
        'dark' => 'dark',
        _ => 'system',
      };
      await HomeWidget.saveWidgetData<String>(
        'widget_theme_preference',
        normalized,
      );
      await _refreshAll();
    } catch (e) {
      debugPrint('Error saving widget theme preference: $e');
    }
  }

  static Future<void> saveLocation(String locationName) async {
    try {
      await _preparePlatform();
      await HomeWidget.saveWidgetData<String>(
        'widget_location',
        locationName.trim(),
      );
      await _refreshAll();
    } catch (e) {
      debugPrint('Error saving widget location: $e');
    }
  }

  static Future<void> clearPrayerData({
    required String languageCode,
    required bool use24HourFormat,
  }) async {
    try {
      await _preparePlatform();
      await HomeWidget.saveWidgetData<String>('prayer_schedule_json', '[]');
      await HomeWidget.saveWidgetData<String>('widget_timezone', '');
      await HomeWidget.saveWidgetData<String>('widget_location', '');
      await HomeWidget.saveWidgetData<String>('next_prayer', '');
      await HomeWidget.saveWidgetData<String>('current_time', '');
      await HomeWidget.saveWidgetData<String>('time_left', '');
      await HomeWidget.saveWidgetData<int>('next_prayer_epoch_ms', 0);
      await HomeWidget.saveWidgetData<int>('next_prayer_at', 0);
      await HomeWidget.saveWidgetData<String>('widget_language', languageCode);
      await HomeWidget.saveWidgetData<bool>('widget_use_24h', use24HourFormat);
      await _refreshAll();
    } catch (e) {
      debugPrint('Error clearing widget prayer data: $e');
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
      await _preparePlatform();
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

      await _refreshAll();
    } catch (e) {
      debugPrint('Error updating widgets: $e');
    }
  }

  static Future<void> _preparePlatform() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await HomeWidget.setAppGroupId(iOSAppGroupId);
    }
  }

  static Future<void> _refreshAll() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await HomeWidget.updateWidget(
        name: _iOSWidgetName,
        iOSName: _iOSWidgetName,
      );
      return;
    }

    for (final name in _androidWidgetNames) {
      await HomeWidget.updateWidget(name: name, androidName: name);
    }
  }
}
