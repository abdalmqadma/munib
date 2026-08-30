import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/notification_service.dart';
import '../../features/prayer_times/data/models/prayer_day.dart';
import '../../features/prayer_times/data/widget_service.dart';
import '../../features/prayer_times/domain/prayer_time_calculator.dart';

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

  SavedImsakiaLocation copyWith({List<PrayerDay>? prayers}) {
    return SavedImsakiaLocation(
      id: id,
      name: name,
      country: country,
      latitude: latitude,
      longitude: longitude,
      timezone: timezone,
      prayers: prayers ?? this.prayers,
    );
  }

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
  static const _morningAzkarMinuteKey = 'morningAzkarMinuteOfDay';
  static const _eveningAzkarMinuteKey = 'eveningAzkarMinuteOfDay';
  static const notificationPrayers = <String>[
    'Fajr',
    'Dhuhr',
    'Asr',
    'Maghrib',
    'Isha',
  ];

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
  final Map<String, bool> _enabledNotificationPrayers = {
    for (final prayer in notificationPrayers) prayer: true,
  };
  final Map<String, int> _reminderMinutes = {
    for (final prayer in notificationPrayers)
      prayer: NotificationService.defaultReminderMinutes,
  };
  int? _morningAzkarMinuteOfDay;
  int _eveningAzkarMinuteOfDay =
      NotificationService.defaultEveningAzkarMinuteOfDay;

  bool prayerNotif = true;
  bool reminderNotif = true;
  bool morningAzkarNotif = false;
  bool eveningAzkarNotif = false;
  bool silentMode = false;
  String adhanVoice = 'Madinah';
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
  DateTime get currentLocationTime =>
      PrayerTimeCalculator.nowForTimezone(_activeTimezone);
  int? get morningAzkarMinuteOfDay => _morningAzkarMinuteOfDay;
  int get eveningAzkarMinuteOfDay => _eveningAzkarMinuteOfDay;
  Set<String> get enabledNotificationPrayers =>
      _enabledNotificationPrayers.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toSet();

  String get languageCode => language == 'English' ? 'en' : 'ar';
  Locale get locale => Locale(languageCode);
  bool get isEnglish => languageCode == 'en';
  ThemeMode get themeMode => isDarkMode ? ThemeMode.dark : ThemeMode.light;

  PrayerProvider() {
    unawaited(_initialize());
    _startTimer();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _readSettings(prefs);
    _readSavedLocations(prefs);

    if (_savedLocations.isNotEmpty) {
      final primary = _savedLocations.first;
      _activeLocationId = primary.id;
      _activeTimezone = primary.timezone;
      currentCity = primary.label;
      await prefs.setString(_activeLocationKey, primary.id);
      await prefs.setString('currentCity', currentCity);
      await WidgetService.saveLocation(primary.name);
      await _applyPrayers(primary.prayers);
    } else {
      _activeLocationId = null;
      _activeTimezone = '';
      await prefs.remove(_activeLocationKey);
      await _loadFromHive();
      await WidgetService.saveLocation(currentCity == 'غير محدد' ? '' : currentCity);
    }

    await WidgetService.savePreferences(
      languageCode: languageCode,
      use24HourFormat: use24HourFormat,
    );
    _updateCurrentStatus(forceWidgetUpdate: true);
    notifyListeners();
  }

  void _readSettings(SharedPreferences prefs) {
    prayerNotif = prefs.getBool('prayerNotif') ?? true;
    reminderNotif = prefs.getBool('reminderNotif') ?? true;
    final legacyAzkar = prefs.getBool('azkarNotif') ?? false;
    morningAzkarNotif = prefs.getBool('morningAzkarNotif') ?? legacyAzkar;
    eveningAzkarNotif = prefs.getBool('eveningAzkarNotif') ?? legacyAzkar;
    silentMode = prefs.getBool('silentMode') ?? false;
    final savedVoice = prefs.getString('adhanVoice');
    adhanVoice = savedVoice == 'Meccan' || savedVoice == 'None'
        ? savedVoice!
        : 'Madinah';
    currentCity = prefs.getString('currentCity') ?? 'غير محدد';
    final savedLanguage = prefs.getString('language') ?? 'ar';
    language = savedLanguage == 'en' || savedLanguage == 'English'
        ? 'English'
        : 'العربية';
    isDarkMode = prefs.getBool('isDarkMode') ?? true;
    use24HourFormat = prefs.getBool('use24HourFormat') ?? true;

    final savedMorning = prefs.getInt(_morningAzkarMinuteKey);
    _morningAzkarMinuteOfDay = savedMorning == null
        ? null
        : savedMorning.clamp(0, 1439).toInt();
    _eveningAzkarMinuteOfDay =
        (prefs.getInt(_eveningAzkarMinuteKey) ??
                NotificationService.defaultEveningAzkarMinuteOfDay)
            .clamp(0, 1439)
            .toInt();

    for (final prayer in notificationPrayers) {
      _enabledNotificationPrayers[prayer] =
          prefs.getBool('prayerNotif_$prayer') ?? true;
      _reminderMinutes[prayer] =
          (prefs.getInt('prayerReminderMinutes_$prayer') ??
                  NotificationService.defaultReminderMinutes)
              .clamp(1, 1440)
              .toInt();
    }
  }

  void _readSavedLocations(SharedPreferences prefs) {
    final savedJson = prefs.getString(_savedLocationsKey);
    if (savedJson == null || savedJson.isEmpty) return;
    try {
      final decoded = jsonDecode(savedJson);
      if (decoded is List) {
        _savedLocations = decoded
            .whereType<Map>()
            .map((e) => SavedImsakiaLocation.fromJson(Map<String, dynamic>.from(e)))
            .where((e) => e.prayers.isNotEmpty)
            .toList();
      }
    } catch (_) {
      _savedLocations = [];
    }
  }

  Future<void> _loadFromHive() async {
    final box = await Hive.openBox<PrayerDay>('prayers');
    _monthlyPrayers = box.values.toList();
    await WidgetService.savePrayerSchedule(
      _monthlyPrayers,
      timezone: _activeTimezone,
    );
    _updateCurrentStatus(forceWidgetUpdate: true);
    await _syncNotifications();
  }

  Future<void> setMonthlyPrayers(List<PrayerDay> prayers) async {
    final activeId = _activeLocationId;
    if (activeId != null) {
      final index = _savedLocations.indexWhere((e) => e.id == activeId);
      if (index >= 0) {
        _savedLocations[index] = _savedLocations[index].copyWith(
          prayers: List<PrayerDay>.from(prayers),
        );
        await _persistSavedLocations();
      }
    }
    await _applyPrayers(prayers);
  }

  Future<void> _applyPrayers(List<PrayerDay> prayers) async {
    _monthlyPrayers = List<PrayerDay>.from(prayers);
    final box = await Hive.openBox<PrayerDay>('prayers');
    await box.clear();
    await box.addAll(_monthlyPrayers);
    await WidgetService.savePrayerSchedule(
      _monthlyPrayers,
      timezone: _activeTimezone,
    );
    _updateCurrentStatus(forceWidgetUpdate: true);
    await _syncNotifications();
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
      prayers: List<PrayerDay>.from(prayers),
    );

    final index = _savedLocations.indexWhere((e) => e.id == id);
    if (index >= 0) {
      _savedLocations[index] = item;
    } else {
      _savedLocations.add(item);
    }

    await _activateLocation(_savedLocations.first, persistLocations: true);
  }

  Future<void> _snapshotCurrentImsakiaIfNeeded() async {
    if (_monthlyPrayers.isEmpty) return;
    const id = 'legacy-current';
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

  Future<void> reorderSavedLocations(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _savedLocations.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex < 0 || newIndex >= _savedLocations.length) return;
    if (oldIndex == newIndex) return;

    final item = _savedLocations.removeAt(oldIndex);
    _savedLocations.insert(newIndex, item);
    notifyListeners();
    await _activateLocation(_savedLocations.first, persistLocations: true);
  }

  Future<void> _activateLocation(
    SavedImsakiaLocation item, {
    required bool persistLocations,
  }) async {
    _activeLocationId = item.id;
    _activeTimezone = item.timezone;
    currentCity = item.label;
    await WidgetService.saveLocation(item.name);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentCity', currentCity);
    await prefs.setString(_activeLocationKey, item.id);
    if (persistLocations) await _persistSavedLocations();
    await _applyPrayers(item.prayers);
  }

  Future<void> removeSavedLocation(String id) async {
    _savedLocations.removeWhere((e) => e.id == id);
    if (_savedLocations.isNotEmpty) {
      await _activateLocation(_savedLocations.first, persistLocations: true);
      return;
    }

    _activeLocationId = null;
    _activeTimezone = '';
    currentCity = 'غير محدد';

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('currentCity');
    await _persistSavedLocations();

    _monthlyPrayers = [];
    _currentDay = null;
    _nextPrayerName = '';
    _nextPrayerTime = null;
    _timeLeft = Duration.zero;
    _lastWidgetStateKey = null;

    final box = await Hive.openBox<PrayerDay>('prayers');
    await box.clear();
    await WidgetService.clearPrayerData(
      languageCode: languageCode,
      use24HourFormat: use24HourFormat,
    );
    await _syncNotifications();
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
    } else {
      await prefs.remove(_activeLocationKey);
    }
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
    await _syncNotifications();
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

  bool isPrayerNotificationEnabled(String prayer) =>
      _enabledNotificationPrayers[prayer] ?? false;

  int reminderMinutesFor(String prayer) =>
      _reminderMinutes[prayer] ?? NotificationService.defaultReminderMinutes;

  bool reminderMinutesConflict(String prayer, int minutes) =>
      NotificationService.hasReminderConflict(
        days: _monthlyPrayers,
        timezone: _activeTimezone,
        prayer: prayer,
        minutes: minutes,
      );

  Future<NotificationPermissionState> requestNotificationPermissions() async {
    final state = await NotificationService.requestPermissions();
    if (state.notificationsAllowed) await _syncNotifications();
    return state;
  }

  Future<bool> setPrayerNotificationsEnabled(bool value) async {
    if (value) {
      final permission = await NotificationService.requestPermissions();
      if (!permission.notificationsAllowed) return false;
    }
    prayerNotif = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('prayerNotif', value);
    await _syncNotifications();
    notifyListeners();
    return true;
  }

  Future<void> setReminderNotificationsEnabled(bool value) async {
    reminderNotif = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminderNotif', value);
    await _syncNotifications();
    notifyListeners();
  }

  Future<bool> setMorningAzkarNotificationsEnabled(bool value) async {
    if (value) {
      final permission = await NotificationService.requestPermissions();
      if (!permission.notificationsAllowed) return false;
    }
    morningAzkarNotif = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('morningAzkarNotif', value);
    await _syncNotifications();
    notifyListeners();
    return true;
  }

  Future<bool> setEveningAzkarNotificationsEnabled(bool value) async {
    if (value) {
      final permission = await NotificationService.requestPermissions();
      if (!permission.notificationsAllowed) return false;
    }
    eveningAzkarNotif = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('eveningAzkarNotif', value);
    await _syncNotifications();
    notifyListeners();
    return true;
  }

  Future<void> setMorningAzkarMinuteOfDay(int? minuteOfDay) async {
    if (minuteOfDay != null && (minuteOfDay < 0 || minuteOfDay > 1439)) return;
    _morningAzkarMinuteOfDay = minuteOfDay;
    final prefs = await SharedPreferences.getInstance();
    if (minuteOfDay == null) {
      await prefs.remove(_morningAzkarMinuteKey);
    } else {
      await prefs.setInt(_morningAzkarMinuteKey, minuteOfDay);
    }
    await _syncNotifications();
    notifyListeners();
  }

  Future<void> setEveningAzkarMinuteOfDay(int minuteOfDay) async {
    if (minuteOfDay < 0 || minuteOfDay > 1439) return;
    _eveningAzkarMinuteOfDay = minuteOfDay;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_eveningAzkarMinuteKey, minuteOfDay);
    await _syncNotifications();
    notifyListeners();
  }

  Future<void> setSilentMode(bool value) async {
    silentMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('silentMode', value);
    await _syncNotifications();
    notifyListeners();
  }

  Future<void> setAdhanVoice(String value) async {
    final normalized = value == 'Meccan' || value == 'None' ? value : 'Madinah';
    adhanVoice = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('adhanVoice', normalized);
    await _syncNotifications();
    notifyListeners();
  }

  Future<void> setPrayerNotificationEnabled(String prayer, bool value) async {
    if (!notificationPrayers.contains(prayer)) return;
    _enabledNotificationPrayers[prayer] = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('prayerNotif_$prayer', value);
    await _syncNotifications();
    notifyListeners();
  }

  Future<bool> setPrayerReminderMinutes(String prayer, int minutes) async {
    if (!notificationPrayers.contains(prayer) ||
        minutes < 1 ||
        minutes > 1440 ||
        reminderMinutesConflict(prayer, minutes)) {
      return false;
    }
    _reminderMinutes[prayer] = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('prayerReminderMinutes_$prayer', minutes);
    await _syncNotifications();
    notifyListeners();
    return true;
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
    if (key == 'prayerNotif' && value is bool) {
      await setPrayerNotificationsEnabled(value);
      return;
    }
    if (key == 'reminderNotif' && value is bool) {
      await setReminderNotificationsEnabled(value);
      return;
    }
    if (key == 'morningAzkarNotif' && value is bool) {
      await setMorningAzkarNotificationsEnabled(value);
      return;
    }
    if (key == 'eveningAzkarNotif' && value is bool) {
      await setEveningAzkarNotificationsEnabled(value);
      return;
    }
    if (key == 'silentMode' && value is bool) {
      await setSilentMode(value);
      return;
    }
    if (key == 'adhanVoice' && value is String) {
      await setAdhanVoice(value);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
      if (key == 'currentCity') {
        currentCity = value;
        await WidgetService.saveLocation(value);
      }
    }
    notifyListeners();
  }

  NotificationScheduleConfig get _notificationConfig => NotificationScheduleConfig(
        prayerNotificationsEnabled: prayerNotif,
        remindersEnabled: reminderNotif,
        morningAzkarEnabled: morningAzkarNotif,
        eveningAzkarEnabled: eveningAzkarNotif,
        silent: silentMode,
        adhanVoice: adhanVoice,
        languageCode: languageCode,
        timezone: _activeTimezone,
        enabledPrayers: enabledNotificationPrayers,
        reminderMinutes: Map.unmodifiable(_reminderMinutes),
        morningAzkarMinuteOfDay: _morningAzkarMinuteOfDay,
        eveningAzkarMinuteOfDay: _eveningAzkarMinuteOfDay,
      );

  Future<void> _syncNotifications() =>
      NotificationService.syncSchedule(_monthlyPrayers, _notificationConfig);

  Duration timeUntilPrayer(String prayerName) =>
      PrayerTimeCalculator.timeUntilPrayer(
        days: _monthlyPrayers,
        timezone: _activeTimezone,
        prayerName: prayerName,
      );

  String formattedTimeUntilPrayer(String prayerName) =>
      _formatDuration(timeUntilPrayer(prayerName));

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCurrentStatus();
    });
  }

  void _updateCurrentStatus({bool forceWidgetUpdate = false}) {
    final now = PrayerTimeCalculator.nowForTimezone(_activeTimezone);
    if (_monthlyPrayers.isEmpty) {
      _currentDay = null;
      _nextPrayerName = '';
      _nextPrayerTime = null;
      _timeLeft = Duration.zero;
      return;
    }

    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    _currentDay = null;
    for (final day in _monthlyPrayers) {
      if (day.date == todayStr) {
        _currentDay = day;
        break;
      }
    }

    if (_currentDay == null) {
      _nextPrayerName = '';
      _nextPrayerTime = null;
      _timeLeft = Duration.zero;
      notifyListeners();
      return;
    }

    final next = PrayerTimeCalculator.nextPrayer(
      days: _monthlyPrayers,
      timezone: _activeTimezone,
      now: now,
    );
    _nextPrayerName = next?.name ?? '';
    _nextPrayerTime = next?.dateTime;
    final remaining = next?.dateTime.difference(now) ?? Duration.zero;
    _timeLeft = remaining.isNegative ? Duration.zero : remaining;
    notifyListeners();

    final widgetStateKey =
        '$_nextPrayerName:${_nextPrayerTime?.millisecondsSinceEpoch ?? 0}:$languageCode:$use24HourFormat';
    if (forceWidgetUpdate || widgetStateKey != _lastWidgetStateKey) {
      _lastWidgetStateKey = widgetStateKey;
      unawaited(WidgetService.updateWidget(
        currentTime: use24HourFormat
            ? DateFormat('HH:mm').format(now)
            : DateFormat('h:mm a', languageCode).format(now),
        nextPrayer: _nextPrayerName,
        timeLeft: timeLeftFormatted,
        nextPrayerTime: _nextPrayerTime,
        languageCode: languageCode,
        use24HourFormat: use24HourFormat,
      ));
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
