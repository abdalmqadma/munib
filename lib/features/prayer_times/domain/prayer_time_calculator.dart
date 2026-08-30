import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../data/models/prayer_day.dart';

class PrayerMoment {
  final String name;
  final String rawTime;
  final DateTime dateTime;

  const PrayerMoment({
    required this.name,
    required this.rawTime,
    required this.dateTime,
  });
}

/// Pure prayer-timeline calculations shared by presentation layers.
///
/// Keeping these rules here prevents screens/widgets from duplicating date,
/// timezone, and prayer-order logic.
class PrayerTimeCalculator {
  static const prayerOrder = <String>[
    'Fajr',
    'Dhuhr',
    'Asr',
    'Maghrib',
    'Isha',
  ];

  const PrayerTimeCalculator._();

  static DateTime nowForTimezone(String timezone) {
    if (timezone.trim().isNotEmpty) {
      try {
        return tz.TZDateTime.now(tz.getLocation(timezone));
      } catch (_) {}
    }
    return DateTime.now();
  }

  static PrayerMoment? nextPrayer({
    required List<PrayerDay> days,
    required String timezone,
    DateTime? now,
  }) {
    if (days.isEmpty) return null;

    final current = now ?? nowForTimezone(timezone);
    final today = _findDay(days, current);
    if (today != null) {
      for (final prayerName in prayerOrder) {
        final rawTime = _rawTime(today, prayerName);
        final parsed = tryParsePrayerTime(
          rawTime: rawTime,
          prayerName: prayerName,
          date: current,
          timezone: timezone,
        );
        if (parsed != null && parsed.isAfter(current)) {
          return PrayerMoment(
            name: prayerName,
            rawTime: rawTime,
            dateTime: parsed,
          );
        }
      }
    }

    final tomorrow = current.add(const Duration(days: 1));
    final tomorrowDay = _findDay(days, tomorrow);
    if (tomorrowDay == null) return null;

    final fajr = tryParsePrayerTime(
      rawTime: tomorrowDay.fajr,
      prayerName: 'Fajr',
      date: tomorrow,
      timezone: timezone,
    );
    if (fajr == null) return null;

    return PrayerMoment(
      name: 'Fajr',
      rawTime: tomorrowDay.fajr,
      dateTime: fajr,
    );
  }

  static Duration timeUntilPrayer({
    required List<PrayerDay> days,
    required String timezone,
    required String prayerName,
    DateTime? now,
  }) {
    if (days.isEmpty) return Duration.zero;

    final current = now ?? nowForTimezone(timezone);
    final today = _findDay(days, current);
    if (today == null) return Duration.zero;

    final rawToday = _rawTime(today, prayerName);
    var target = tryParsePrayerTime(
      rawTime: rawToday,
      prayerName: prayerName,
      date: current,
      timezone: timezone,
    );
    if (target == null) return Duration.zero;

    if (!target.isAfter(current)) {
      final tomorrow = current.add(const Duration(days: 1));
      final tomorrowDay = _findDay(days, tomorrow);
      if (tomorrowDay == null) return Duration.zero;
      target = tryParsePrayerTime(
        rawTime: _rawTime(tomorrowDay, prayerName),
        prayerName: prayerName,
        date: tomorrow,
        timezone: timezone,
      );
      if (target == null) return Duration.zero;
    }

    final difference = target.difference(current);
    return difference.isNegative ? Duration.zero : difference;
  }

  static DateTime? tryParsePrayerTime({
    required String rawTime,
    required String prayerName,
    required DateTime date,
    required String timezone,
  }) {
    try {
      final parsed = DateFormat('HH:mm').parseStrict(rawTime.trim());
      var hour = parsed.hour;
      if (const ['Asr', 'Maghrib', 'Isha'].contains(prayerName) && hour < 12) {
        hour += 12;
      }
      if (prayerName == 'Dhuhr' && hour < 10) hour += 12;

      if (timezone.trim().isNotEmpty) {
        try {
          final location = tz.getLocation(timezone);
          return tz.TZDateTime(
            location,
            date.year,
            date.month,
            date.day,
            hour,
            parsed.minute,
          );
        } catch (_) {}
      }

      return DateTime(date.year, date.month, date.day, hour, parsed.minute);
    } catch (_) {
      return null;
    }
  }

  static PrayerDay? _findDay(List<PrayerDay> days, DateTime date) {
    final key = DateFormat('yyyy-MM-dd').format(date);
    for (final day in days) {
      if (day.date == key) return day;
    }
    return null;
  }

  static String _rawTime(PrayerDay day, String prayerName) {
    switch (prayerName.toLowerCase()) {
      case 'fajr':
        return day.fajr;
      case 'sunrise':
        return day.sunrise;
      case 'dhuhr':
        return day.dhuhr;
      case 'asr':
        return day.asr;
      case 'maghrib':
        return day.maghrib;
      case 'isha':
        return day.isha;
      default:
        return '';
    }
  }
}
