import 'package:flutter_test/flutter_test.dart';
import 'package:munib/data/models/prayer_day.dart';
import 'package:munib/features/prayer_times/domain/prayer_time_calculator.dart';

void main() {
  final days = <PrayerDay>[
    PrayerDay(
      date: '2026-08-30',
      fajr: '04:30',
      sunrise: '05:55',
      dhuhr: '12:00',
      asr: '15:30',
      maghrib: '18:20',
      isha: '19:45',
    ),
    PrayerDay(
      date: '2026-08-31',
      fajr: '04:31',
      sunrise: '05:56',
      dhuhr: '12:00',
      asr: '15:29',
      maghrib: '18:19',
      isha: '19:44',
    ),
  ];

  test('returns next prayer later on the same day', () {
    final next = PrayerTimeCalculator.nextPrayer(
      days: days,
      timezone: '',
      now: DateTime(2026, 8, 30, 13),
    );

    expect(next, isNotNull);
    expect(next!.name, 'Asr');
    expect(next.rawTime, '15:30');
    expect(next.dateTime, DateTime(2026, 8, 30, 15, 30));
  });

  test('rolls over to tomorrow Fajr after Isha', () {
    final next = PrayerTimeCalculator.nextPrayer(
      days: days,
      timezone: '',
      now: DateTime(2026, 8, 30, 21),
    );

    expect(next, isNotNull);
    expect(next!.name, 'Fajr');
    expect(next.rawTime, '04:31');
    expect(next.dateTime, DateTime(2026, 8, 31, 4, 31));
  });

  test('calculates duration until a selected prayer', () {
    final duration = PrayerTimeCalculator.timeUntilPrayer(
      days: days,
      timezone: '',
      prayerName: 'Maghrib',
      now: DateTime(2026, 8, 30, 18),
    );

    expect(duration, const Duration(minutes: 20));
  });

  test('returns zero for an unknown prayer', () {
    final duration = PrayerTimeCalculator.timeUntilPrayer(
      days: days,
      timezone: '',
      prayerName: 'Unknown',
      now: DateTime(2026, 8, 30, 18),
    );

    expect(duration, Duration.zero);
  });
}
