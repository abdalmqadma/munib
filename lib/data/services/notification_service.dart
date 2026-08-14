import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/prayer_day.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _notificationsPlugin.initialize(const InitializationSettings(android: androidSettings, iOS: iosSettings));
  }

  static Future<void> scheduleDailyPrayers(PrayerDay day) async {
    await _notificationsPlugin.cancelAll();
    final now = DateTime.now();
    final prayers = {'Fajr': day.fajr, 'Dhuhr': day.dhuhr, 'Asr': day.asr, 'Maghrib': day.maghrib, 'Isha': day.isha};

    int id = 0;
    for (var entry in prayers.entries) {
      final prayerTime = _parseTime(entry.value, now);
      if (prayerTime.isAfter(now)) {
        await _schedule(id++, "Prayer Time", "It is time for ${entry.key}", prayerTime);
        final tenMinBefore = prayerTime.subtract(const Duration(minutes: 10));
        if (tenMinBefore.isAfter(now)) {
          await _schedule(id++, "Reminder", "10 minutes left for ${entry.key}", tenMinBefore);
        }
      }
    }
  }

  static Future<void> _schedule(int id, String title, String body, DateTime time) async {
    await _notificationsPlugin.zonedSchedule(
      id, title, body, tz.TZDateTime.from(time, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails('prayer_channel', 'Prayers', importance: Importance.max, priority: Priority.high),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static DateTime _parseTime(String timeStr, DateTime today) {
    final parts = timeStr.split(':');
    return DateTime(today.year, today.month, today.day, int.parse(parts[0]), int.parse(parts[1]));
  }
}
