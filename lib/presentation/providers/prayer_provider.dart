import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/prayer_day.dart';

import '../../data/services/widget_service.dart';
import '../../data/services/notification_service.dart';

class PrayerProvider with ChangeNotifier {
  List<PrayerDay> _monthlyPrayers = [];
  PrayerDay? _currentDay;
  String _nextPrayerName = "";
  Duration _timeLeft = Duration.zero;
  Timer? _timer;

  // Settings state
  bool prayerNotif = true;
  bool reminderNotif = true;
  bool azkarNotif = false;
  bool silentMode = false;
  String adhanVoice = 'Meccan';
  String currentCity = "غير محدد";
  String language = 'العربية';
  bool isDarkMode = true;

  List<PrayerDay> get monthlyPrayers => _monthlyPrayers;
  PrayerDay? get currentDay => _currentDay;
  String get nextPrayerName => _nextPrayerName;
  String get timeLeftFormatted => _formatDuration(_timeLeft);

  PrayerProvider() {
    _loadFromHive();
    _loadSettings();
    _startTimer();
  }

  Future<void> _loadFromHive() async {
    final box = await Hive.openBox<PrayerDay>('prayers');
    _monthlyPrayers = box.values.toList();
    _updateCurrentStatus();
  }

  Future<void> setMonthlyPrayers(List<PrayerDay> prayers) async {
    _monthlyPrayers = prayers;
    final box = await Hive.openBox<PrayerDay>('prayers');
    await box.clear();
    await box.addAll(prayers);
    _updateCurrentStatus();
    if (_currentDay != null && prayerNotif) {
      NotificationService.scheduleDailyPrayers(_currentDay!);
    }
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    prayerNotif = prefs.getBool('prayerNotif') ?? true;
    reminderNotif = prefs.getBool('reminderNotif') ?? true;
    azkarNotif = prefs.getBool('azkarNotif') ?? false;
    silentMode = prefs.getBool('silentMode') ?? false;
    adhanVoice = prefs.getString('adhanVoice') ?? 'Meccan';
    currentCity = prefs.getString('currentCity') ?? "غير محدد";
    language = prefs.getString('language') == 'en' ? 'English' : 'العربية';
    isDarkMode = prefs.getBool('isDarkMode') ?? true;
    notifyListeners();
  }

  Future<void> updateSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
      if (key == 'prayerNotif') prayerNotif = value;
      if (key == 'reminderNotif') reminderNotif = value;
      if (key == 'azkarNotif') azkarNotif = value;
      if (key == 'silentMode') silentMode = value;
      if (key == 'isDarkMode') isDarkMode = value;
    } else if (value is String) {
      await prefs.setString(key, value);
      if (key == 'adhanVoice') adhanVoice = value;
      if (key == 'currentCity') currentCity = value;
      if (key == 'language') language = value;
    }
    notifyListeners();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateCurrentStatus();
    });
  }

  void _updateCurrentStatus() {
    final now = DateTime.now();
    if (_monthlyPrayers.isEmpty) return;

    String todayStr = DateFormat('yyyy-MM-dd').format(now);
    _currentDay = _monthlyPrayers.firstWhere(
      (p) => p.date == todayStr, 
      orElse: () => _monthlyPrayers.first
    );

    _calculateNextPrayer(now);
    
    // Check if we need to notify listeners for time update
    notifyListeners();

    WidgetService.updateWidget(
      currentTime: DateFormat('HH:mm').format(now),
      nextPrayer: _nextPrayerName,
      timeLeft: timeLeftFormatted,
    );
  }

  void _calculateNextPrayer(DateTime now) {
    if (_currentDay == null) return;

    final prayers = {
      'Fajr': _currentDay!.fajr,
      'Sunrise': _currentDay!.sunrise,
      'Dhuhr': _currentDay!.dhuhr,
      'Asr': _currentDay!.asr,
      'Maghrib': _currentDay!.maghrib,
      'Isha': _currentDay!.isha,
    };

    DateTime? nextTime;
    String nextName = "";

    for (var entry in prayers.entries) {
      final prayerTime = _parseTime(entry.value, now, entry.key);
      if (prayerTime.isAfter(now)) {
        nextTime = prayerTime;
        nextName = entry.key;
        break;
      }
    }

    if (nextTime == null) {
      // If all prayers passed today, next is tomorrow's Fajr
      _nextPrayerName = "Fajr";
      
      final tomorrowStr = DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 1)));
      try {
        final tomorrowData = _monthlyPrayers.firstWhere((p) => p.date == tomorrowStr);
        final tomorrowFajr = _parseTime(tomorrowData.fajr, now.add(const Duration(days: 1)), 'Fajr');
        _timeLeft = tomorrowFajr.difference(now);
      } catch (e) {
        // Fallback if no tomorrow data exists
        _timeLeft = Duration.zero; 
      }
    } else {
      _nextPrayerName = nextName;
      _timeLeft = nextTime.difference(now);
    }

    // Always update widget when calculation happens
    WidgetService.updateWidget(
      currentTime: DateFormat('HH:mm').format(now),
      nextPrayer: _nextPrayerName,
      timeLeft: timeLeftFormatted,
    );
  }

  DateTime _parseTime(String timeStr, DateTime referenceDate, String prayerName) {
    try {
      final format = DateFormat("HH:mm");
      final parsed = format.parse(timeStr.trim());
      int hour = parsed.hour;

      // Smart 24h conversion for Palestinian Imsakiahs
      // If Asr, Maghrib, or Isha have hours 1-11, they are PM (add 12)
      if (['Asr', 'Maghrib', 'Isha'].contains(prayerName) && hour < 12) {
        hour += 12;
      }
      // Dhuhr is 12 PM unless it's very early/late
      if (prayerName == 'Dhuhr' && hour < 10) {
        hour += 12;
      }

      return DateTime(
        referenceDate.year,
        referenceDate.month,
        referenceDate.day,
        hour,
        parsed.minute,
      );
    } catch (e) {
      // Fallback if parsing fails
      return referenceDate.add(const Duration(days: 1));
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
