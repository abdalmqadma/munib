import 'package:flutter_test/flutter_test.dart';
import 'package:munib/data/services/prayer_time_validator.dart';

void main() {
  final validator = PrayerTimeValidator();

  test('accepts a valid prayer day', () {
    final warnings = validator.validateDay({
      'date': '2026-03-01',
      'fajr': '04:30',
      'sunrise': '05:55',
      'dhuhr': '12:40',
      'asr': '16:15',
      'maghrib': '19:20',
      'isha': '20:45',
    });

    expect(warnings, isEmpty);
  });

  test('rejects invalid order and missing values', () {
    final warnings = validator.validateDay({
      'date': '2026-03-01',
      'fajr': '05:00',
      'sunrise': '04:55',
      'dhuhr': '',
      'asr': '16:15',
      'maghrib': '19:20',
      'isha': '20:45',
    });

    expect(warnings, contains('الشروق يجب أن يأتي بعد الفجر'));
    expect(warnings.any((item) => item.contains('الظهر غير موجود')), isTrue);
  });

  test('detects duplicate dates', () {
    final warnings = validator.validateAll([
      {
        'date': '2026-03-01',
        'fajr': '04:30',
        'sunrise': '05:55',
        'dhuhr': '12:40',
        'asr': '16:15',
        'maghrib': '19:20',
        'isha': '20:45',
      },
      {
        'date': '2026-03-01',
        'fajr': '04:29',
        'sunrise': '05:54',
        'dhuhr': '12:40',
        'asr': '16:16',
        'maghrib': '19:21',
        'isha': '20:46',
      },
    ]);

    expect(warnings.any((item) => item.contains('التاريخ مكرر')), isTrue);
  });
}
