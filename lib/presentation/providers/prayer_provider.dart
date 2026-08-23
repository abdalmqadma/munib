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
  DateTime? _nextPrayerTime;
  String? _lastWidgetStateKey;
  Timer? _timer;

  bool prayerNotif = true;
  bool reminderNotif = true;
  bool azkarNotif = false;
  bool silentMode = false;
  String adhanVoice = 'Meccan';
  String currentCity = "غير محدد";
  String language = 'العربية';
  bool isDarkMode = true;
  bool use24HourFormat = true;

  List<PrayerDay> get monthlyPrayers => _monthlyPrayers;
  PrayerDay? get currentDay => _currentDay;
  String get nextPrayerName => _nextPrayerName;
  String get timeLeftFormatted => _formatDuration(_timeLeft);

  String get languageCode => language == 'English' ? 'en' : 'ar';
  Locale get locale => Locale(languageCode);
  bool get isEnglish => languageCode == 'en';
  ThemeMode get themeMode => isDarkMode ? ThemeMode.dark : ThemeMode.light;

  PrayerProvider() {
    _loadFromHive();
    _loadSettings();
    _startTimer();
  }

  Future<void> _loadFromHive() async {
    final box = await Hive.openBox<PrayerDay>('prayers');
    _monthlyPrayers = box.values.toList();
    await WidgetService.savePrayerSchedule(_monthlyPrayers);
    _updateCurrentStatus(forceWidgetUpdate: true);
  }

  Future<void> setMonthlyPrayers(List<PrayerDay> prayers) async {
    _monthlyPrayers = prayers;
    final box = await Hive.openBox<PrayerDay>('prayers');
    await box.clear();
    await box.addAll(prayers);
    await WidgetService.savePrayerSchedule(_monthlyPrayers);
    _updateCurrentStatus(forceWidgetUpdate: true);
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
    final savedLanguage = prefs.getString('language') ?? 'ar';
    language = savedLanguage == 'en' || savedLanguage == 'English' ? 'English' : 'العربية';
    isDarkMode = prefs.getBool('isDarkMode') ?? true;
    use24HourFormat = prefs.getBool('use24HourFormat') ?? true;
    await WidgetService.savePreferences(
      languageCode: languageCode,
      use24HourFormat: use24HourFormat,
    );
    _updateCurrentStatus(forceWidgetUpdate: true);
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    final normalized = code.toLowerCase() == 'en' || code == 'English' ? 'en' : 'ar';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', normalized);
    language = normalized == 'en' ? 'English' : 'العربية';
    await WidgetService.savePreferences(
      languageCode: languageCode,
      use24HourFormat: use24HourFormat,
    );
    _updateCurrentStatus(forceWidgetUpdate: true);
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
    isDarkMode = value;
    notifyListeners();
  }

  Future<void> setUse24HourFormat(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use24HourFormat', value);
    use24HourFormat = value;
    await WidgetService.savePreferences(
      languageCode: languageCode,
      use24HourFormat: use24HourFormat,
    );
    _updateCurrentStatus(forceWidgetUpdate: true);
    notifyListeners();
  }

  String formatPrayerTime(String rawTime) {
    final value = rawTime.trim();
    if (value.isEmpty || use24HourFormat) return value;

    try {
      final parsed = DateFormat('HH:mm').parseStrict(value);
      return DateFormat('h:mm a', languageCode).format(parsed);
    } catch (_) {
      return value;
    }
  }

  Future<void> updateSetting(String key, dynamic value) async {
    if (key == 'language' && value is String) {
      await setLanguage(value);
      return;
    }
    if (key == 'isDarkMode' && value is bool) {
      await setDarkMode(value);
      return;
    }
    if (key == 'use24HourFormat' && value is bool) {
      await setUse24HourFormat(value);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
      if (key == 'prayerNotif') prayerNotif = value;
      if (key == 'reminderNotif') reminderNotif = value;
      if (key == 'azkarNotif') azkarNotif = value;
      if (key == 'silentMode') silentMode = value;
    } else if (value is String) {
      await prefs.setString(key, value);
      if (key == 'adhanVoice') adhanVoice = value;
      if (key == 'currentCity') currentCity = value;
    }
    notifyListeners();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateCurrentStatus();
    });
  }

  void _updateCurrentStatus({bool forceWidgetUpdate = false}) {
    final now = DateTime.now();
    if (_monthlyPrayers.isEmpty) return;

    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    _currentDay = _monthlyPrayers.firstWhere(
      (p) => p.date == todayStr,
      orElse: () => _monthlyPrayers.first,
    );

    _calculateNextPrayer(now);
    notifyListeners();

    final widgetStateKey =
        '$_nextPrayerName:${_nextPrayerTime?.millisecondsSinceEpoch ?? 0}:$languageCode:$use24HourFormat';
    if (forceWidgetUpdate || widgetStateKey != _lastWidgetStateKey) {
      _lastWidgetStateKey = widgetStateKey;
      WidgetService.updateWidget(
        currentTime: use24HourFormat
            ? DateFormat('HH:mm').format(now)
            : DateFormat('h:mm a', languageCode).format(now),
        nextPrayer: _nextPrayerName,
        timeLeft: timeLeftFormatted,
        nextPrayerTime: _nextPrayerTime,
        languageCode: languageCode,
        use24HourFormat: use24HourFormat,
      );
    }
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
      _nextPrayerName = "Fajr";
      final tomorrowStr = DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 1)));
      try {
        final tomorrowData = _monthlyPrayers.firstWhere((p) => p.date == tomorrowStr);
        final tomorrowFajr = _parseTime(
          tomorrowData.fajr,
          now.add(const Duration(days: 1)),
          'Fajr',
        );
        _nextPrayerTime = tomorrowFajr;
        _timeLeft = tomorrowFajr.difference(now);
      } catch (_) {
        _nextPrayerTime = null;
        _timeLeft = Duration.zero;
      }
    } else {
      _nextPrayerName = nextName;
      _nextPrayerTime = nextTime;
      _timeLeft = nextTime.difference(now);
    }
  }

  DateTime _parseTime(String timeStr, DateTime referenceDate, String prayerName) {
    try {
      final format = DateFormat("HH:mm");
      final parsed = format.parse(timeStr.trim());
      int hour = parsed.hour;

      if (['Asr', 'Maghrib', 'Isha'].contains(prayerName) && hour < 12) {
        hour += 12;
      }
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
    } catch (_) {
      return referenceDate.add(const Duration(days: 1));
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    final twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
