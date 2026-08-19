class PrayerTimeValidator {
  static const prayerKeys = [
    'fajr',
    'sunrise',
    'dhuhr',
    'asr',
    'maghrib',
    'isha',
  ];

  List<String> validateDay(Map<String, dynamic> day) {
    final warnings = <String>[];
    final date = day['date']?.toString() ?? '';

    if (!_isIsoDate(date)) {
      warnings.add('التاريخ غير صالح');
    }

    final parsed = <String, int>{};
    for (final key in prayerKeys) {
      final value = day[key]?.toString().trim() ?? '';
      final minutes = _parseMinutes(value);
      if (minutes == null) {
        warnings.add('${_arabicName(key)} غير موجود أو غير صالح');
      } else {
        parsed[key] = minutes;
      }
    }

    for (var i = 1; i < prayerKeys.length; i++) {
      final previous = parsed[prayerKeys[i - 1]];
      final current = parsed[prayerKeys[i]];
      if (previous != null && current != null && current <= previous) {
        warnings.add(
          '${_arabicName(prayerKeys[i])} يجب أن يأتي بعد ${_arabicName(prayerKeys[i - 1])}',
        );
      }
    }

    return warnings;
  }

  List<String> validateAll(List<Map<String, dynamic>> days) {
    final warnings = <String>[];
    final seenDates = <String>{};

    for (var index = 0; index < days.length; index++) {
      final dayWarnings = validateDay(days[index]);
      for (final warning in dayWarnings) {
        warnings.add('اليوم ${index + 1}: $warning');
      }

      final date = days[index]['date']?.toString() ?? '';
      if (date.isNotEmpty && !seenDates.add(date)) {
        warnings.add('اليوم ${index + 1}: التاريخ مكرر');
      }
    }

    return warnings;
  }

  int? _parseMinutes(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})\$').firstMatch(value);
    if (match == null) return null;

    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return null;
    }

    return hour * 60 + minute;
  }

  bool _isIsoDate(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})\$').firstMatch(value);
    if (match == null) return false;

    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);
    if (year == null || month == null || day == null) return false;
    if (month < 1 || month > 12 || day < 1 || day > 31) return false;

    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day;
  }

  String _arabicName(String key) {
    const names = {
      'fajr': 'الفجر',
      'sunrise': 'الشروق',
      'dhuhr': 'الظهر',
      'asr': 'العصر',
      'maghrib': 'المغرب',
      'isha': 'العشاء',
    };
    return names[key] ?? key;
  }
}
