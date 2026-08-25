import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/prayer_day.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/widget_service.dart';

class SavedImsakiaLocation {
  final String id;
  final String name;
  final String country;
  final double latitude;
  final double longitude;
  final String timezone;
  final List<PrayerDay> prayers;

  const SavedImsakiaLocation({
    required this.id,
    required this.name,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.timezone,
    required this.prayers,
  });

  String get label => country.trim().isEmpty ? name : '$name, $country';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'country': country,
        'latitude': latitude,
        'longitude': longitude,
        'timezone': timezone,
        'prayers': prayers.map((e) => e.toJson()).toList(),
      };

  factory SavedImsakiaLocation.fromJson(Map<String, dynamic> json) {
    final rawPrayers = json['prayers'] is List ? json['prayers'] as List : const [];
    return SavedImsakiaLocation(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      country: (json['country'] ?? '').toString(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      timezone: (json['timezone'] ?? '').toString(),
      prayers: rawPrayers
          .whereType<Map>()
          .map((e) => PrayerDay.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class PrayerProvider with ChangeNotifier {
  static const _savedLocationsKey = 'savedImsakiaLocationsV1';
  static const _activeLocationKey = 'activeImsakiaLocationId';

  List<PrayerDay> _monthlyPrayers = [];
  PrayerDay? _currentDay;
  String _nextPrayerName = '';
  Duration _timeLeft = Duration.zero;
  DateTime? _nextPrayerTime;
  String? _lastWidgetStateKey;
  Timer? _timer;
  List<SavedImsakiaLocation> _savedLocations = [];
  String? _activeLocationId;
  String _activeTimezone = '';

  bool prayerNotif = true;
  bool reminderNotif = true;
  bool azkarNotif = false;
  bool silentMode = false;
  String adhanVoice = 'Meccan';
  String currentCity = 'غير محدد';
  String language = 'العربية';
  bool isDarkMode = true;
  bool use24HourFormat = true;

  List<PrayerDay> get monthlyPrayers => _monthlyPrayers;
  PrayerDay? get currentDay => _currentDay;
  String get nextPrayerName => _nextPrayerName;
  String get timeLeftFormatted => _formatDuration(_timeLeft);
  List<SavedImsakiaLocation> get savedLocations => List.unmodifiable(_savedLocations);
  String? get activeLocationId => _activeLocationId;
  String get activeTimezone => _activeTimezone;

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
    await _applyPrayers(prayers);
  }

  Future<void> _applyPrayers(List<PrayerDay> prayers) async {
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

  Future<void> addLocationImsakia({
    required String name,
    required String country,
    required double latitude,
    required double longitude,
    required String timezone,
    required List<PrayerDay> prayers,
  }) async {
    if (_monthlyPrayers.isNotEmpty && _savedLocations.isEmpty) {
      await _snapshotCurrentImsakiaIfNeeded();
    }

    final id = '${latitude.toStringAsFixed(5)}:${longitude.toStringAsFixed(5)}';
    final item = SavedImsakiaLocation(
      id: id,
      name: name.trim().isEmpty ? country : name.trim(),
      country: country.trim(),
      latitude: latitude,
      longitude: longitude,
      timezone: timezone,
      prayers: prayers,
    );

    final index = _savedLocations.indexWhere((e) => e.id == id);
    if (index >= 0) {
      _savedLocations[index] = item;
    } else {
      _savedLocations.add(item);
    }

    await _activateLocation(item, persistLocations: true);
  }

  Future<void> _snapshotCurrentImsakiaIfNeeded() async {
    if (_monthlyPrayers.isEmpty) return;
    final id = 'legacy-current';
    if (_savedLocations.any((e) => e.id == id)) return;
    final fallbackName = currentCity.trim().isEmpty || currentCity == 'غير محدد'
        ? (isEnglish ? 'Current Imsakia' : 'الإمساكية الحالية')
        : currentCity;
    _savedLocations.add(SavedImsakiaLocation(
      id: id,
      name: fallbackName,
      country: '',
      latitude: 0,
      longitude: 0,
      timezone: _activeTimezone,
      prayers: List<PrayerDay>.from(_monthlyPrayers),
    ));
    _activeLocationId ??= id;
    await _persistSavedLocations();
  }

  Future<void> activateSavedLocation(String id) async {
    final item = _savedLocations.where((e) => e.id == id).firstOrNull;
    if (item == null) return;
    await _activateLocation(item, persistLocations: false);
  }

  Future<void> _activateLocation(
    SavedImsakiaLocation item, {
    required bool persistLocations,
  }) async {
    _activeLocationId = item.id;
    _activeTimezone = item.timezone;
    currentCity = item.label;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentCity', currentCity);
    await prefs.setString(_activeLocationKey, item.id);
    if (persistLocations) await _persistSavedLocations();
    await _applyPrayers(item.prayers);
  }

  Future<void> removeSavedLocation(String id) async {
    final wasActive = _activeLocationId == id;
    _savedLocations.removeWhere((e) => e.id == id);
    if (wasActive) {
      if (_savedLocations.isNotEmpty) {
        await _activateLocation(_savedLocations.first, persistLocations: false);
      } else {
        _activeLocationId = null;
        _activeTimezone = '';
      }
    }
    await _persistSavedLocations();
    notifyListeners();
  }

  Future<void> _persistSavedLocations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _savedLocationsKey,
      jsonEncode(_savedLocations.map((e) => e.toJson()).toList()),
    );
    if (_activeLocationId != null) {
      await prefs.setString(_activeLocationKey, _activeLocationId!);
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    prayerNotif = prefs.getBool('prayerNotif') ?? true;
    reminderNotif = prefs.getBool('reminderNotif') ?? true;
    azkarNotif = prefs.getBool('azkarNotif') ?? false;
    silentMode = prefs.getBool('silentMode') ?? false;
    adhanVoice = prefs.getString('adhanVoice') ?? 'Meccan';
    currentCity = prefs.getString('currentCity') ?? 'غير محدد';
    final savedLanguage = prefs.getString('language') ?? 'ar';
    language = savedLanguage == 'en' || savedLanguage == 'English' ? 'English' : 'العربية';
    isDarkMode = prefs.getBool('isDarkMode') ?? true;
    use24HourFormat = prefs.getBool('use24HourFormat') ?? true;

    final savedJson = prefs.getString(_savedLocationsKey);
    if (savedJson != null && savedJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(savedJson);
        if (decoded is List) {
          _savedLocations = decoded
              .whereType<Map>()
              .map((e) => SavedImsakiaLocation.fromJson(Map<String, dynamic>.from(e)))
              .where((e) => e.prayers.isNotEmpty)
              .toList();
        }
      } catch (_) {}
    }
    _activeLocationId = prefs.getString(_activeLocationKey);
    if (_activeLocationId != null) {
      final matches = _savedLocations.where((e) => e.id == _activeLocationId);
      if (matches.isNotEmpty) {
        final active = matches.first;
        _activeTimezone = active.timezone;
        currentCity = active.label;
        await _applyPrayers(active.prayers);
      }
    }

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

  DateTime _nowForActiveLocation() {
    if (_activeTimezone.trim().isNotEmpty) {
      try {
        return tz.TZDateTime.now(tz.getLocation(_activeTimezone));
      } catch (_) {}
    }
    return DateTime.now();
  }

  Duration timeUntilPrayer(String prayerName) {
    if (_monthlyPrayers.isEmpty) return Duration.zero;
    final now = _nowForActiveLocation();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final today = _monthlyPrayers.where((p) => p.date == todayStr).firstOrNull ?? _currentDay;
    if (today == null) return Duration.zero;

    String rawFor(PrayerDay day) {
      switch (prayerName.toLowerCase()) {
        case 'fajr': return day.fajr;
        case 'sunrise': return day.sunrise;
        case 'dhuhr': return day.dhuhr;
        case 'asr': return day.asr;
        case 'maghrib': return day.maghrib;
        case 'isha': return day.isha;
        default: return '';
      }
    }

    var target = _parseTime(rawFor(today), now, prayerName);
    if (!target.isAfter(now)) {
      final tomorrowReference = now.add(const Duration(days: 1));
      final tomorrowStr = DateFormat('yyyy-MM-dd').format(tomorrowReference);
      final tomorrow = _monthlyPrayers.where((p) => p.date == tomorrowStr).firstOrNull;
      target = _parseTime(rawFor(tomorrow ?? today), tomorrowReference, prayerName);
    }
    return target.difference(now).isNegative ? Duration.zero : target.difference(now);
  }

  String formattedTimeUntilPrayer(String prayerName) => _formatDuration(timeUntilPrayer(prayerName));

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCurrentStatus();
    });
  }

  void _updateCurrentStatus({bool forceWidgetUpdate = false}) {
    final now = _nowForActiveLocation();
    if (_monthlyPrayers.isEmpty) return;

    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    _currentDay = _monthlyPrayers.firstWhere(
      (p) => p.date == todayStr,
      orElse: () => _monthlyPrayers.first,
    );

    _calculateNextPrayer(now);
    notifyListeners();

    final widgetStateKey = '$_nextPrayerName:${_nextPrayerTime?.millisecondsSinceEpoch ?? 0}:$languageCode:$use24HourFormat';
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
    String nextName = '';
    for (final entry in prayers.entries) {
      final prayerTime = _parseTime(entry.value, now, entry.key);
      if (prayerTime.isAfter(now)) {
        nextTime = prayerTime;
        nextName = entry.key;
        break;
      }
    }

    if (nextTime == null) {
      _nextPrayerName = 'Fajr';
      final tomorrowReference = now.add(const Duration(days: 1));
      final tomorrowStr = DateFormat('yyyy-MM-dd').format(tomorrowReference);
      try {
        final tomorrowData = _monthlyPrayers.firstWhere((p) => p.date == tomorrowStr);
        final tomorrowFajr = _parseTime(tomorrowData.fajr, tomorrowReference, 'Fajr');
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
      final parsed = DateFormat('HH:mm').parse(timeStr.trim());
      int hour = parsed.hour;
      if (['Asr', 'Maghrib', 'Isha'].contains(prayerName) && hour < 12) hour += 12;
      if (prayerName == 'Dhuhr' && hour < 10) hour += 12;

      if (_activeTimezone.trim().isNotEmpty) {
        try {
          final location = tz.getLocation(_activeTimezone);
          return tz.TZDateTime(
            location,
            referenceDate.year,
            referenceDate.month,
            referenceDate.day,
            hour,
            parsed.minute,
          );
        } catch (_) {}
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
    final safe = duration.isNegative ? Duration.zero : duration;
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(safe.inMinutes.remainder(60));
    final seconds = twoDigits(safe.inSeconds.remainder(60));
    return '${twoDigits(safe.inHours)}:$minutes:$seconds';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
