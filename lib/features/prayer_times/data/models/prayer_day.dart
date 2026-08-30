import 'package:hive/hive.dart';

part 'prayer_day.g.dart';

@HiveType(typeId: 0)
class PrayerDay extends HiveObject {
  @HiveField(0)
  final String date;

  @HiveField(1)
  final String fajr;

  @HiveField(2)
  final String sunrise;

  @HiveField(3)
  final String dhuhr;

  @HiveField(4)
  final String asr;

  @HiveField(5)
  final String maghrib;

  @HiveField(6)
  final String isha;

  PrayerDay({
    required this.date,
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  factory PrayerDay.fromJson(Map<String, dynamic> json) {
    return PrayerDay(
      date: json['date'] ?? '',
      fajr: json['fajr'] ?? '',
      sunrise: json['sunrise'] ?? '',
      dhuhr: json['dhuhr'] ?? '',
      asr: json['asr'] ?? '',
      maghrib: json['maghrib'] ?? '',
      isha: json['isha'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'fajr': fajr,
      'sunrise': sunrise,
      'dhuhr': dhuhr,
      'asr': asr,
      'maghrib': maghrib,
      'isha': isha,
    };
  }
}
