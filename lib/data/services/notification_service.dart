import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/prayer_day.dart';
import 'adhan_bridge_service.dart';
import 'nafahat_bridge_service.dart';

class NotificationPermissionState {
  final bool notificationsAllowed;
  final bool exactAlarmsAllowed;

  const NotificationPermissionState({
    required this.notificationsAllowed,
    required this.exactAlarmsAllowed,
  });
}

class NotificationScheduleConfig {
  final bool prayerNotificationsEnabled;
  final bool remindersEnabled;
  final bool morningAzkarEnabled;
  final bool eveningAzkarEnabled;
  final bool silent;
  final String adhanVoice;
  final String languageCode;
  final String timezone;
  final Set<String> enabledPrayers;
  final Map<String, int> reminderMinutes;
  final int? morningAzkarMinuteOfDay;
  final int eveningAzkarMinuteOfDay;

  const NotificationScheduleConfig({
    required this.prayerNotificationsEnabled,
    required this.remindersEnabled,
    required this.morningAzkarEnabled,
    required this.eveningAzkarEnabled,
    required this.silent,
    required this.adhanVoice,
    required this.languageCode,
    required this.timezone,
    required this.enabledPrayers,
    required this.reminderMinutes,
    required this.morningAzkarMinuteOfDay,
    required this.eveningAzkarMinuteOfDay,
  });
}

class NotificationService {
  static const int defaultReminderMinutes = 15;
  static const int defaultMorningAzkarDelayMinutes = 15;
  static const int defaultEveningAzkarMinuteOfDay = 17 * 60;
  static const String _managedIdsKey = 'notification_managed_ids_v2';
  static const String _reminderChannelId = 'prayer_reminders_v2';
  static const String _azkarChannelId = 'daily_azkar_v2';
  static const int _nativeAlarmBaseId = 60000;
  static const int _reminderBaseId = 1000;
  static const int _azkarBaseId = 20000;

  static const _adhanBridge = AdhanBridgeService();
  static const _nafahatBridge = NafahatBridgeService();
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _captureAzkarPayload(launchDetails?.notificationResponse?.payload);
    }
    _initialized = true;
  }

  static void _onNotificationResponse(NotificationResponse response) {
    _captureAzkarPayload(response.payload);
  }

  static void _captureAzkarPayload(String? payload) {
    final category = switch (payload) {
      'azkar:Morning' => 'Morning',
      'azkar:Evening' => 'Evening',
      _ => null,
    };
    if (category != null) {
      unawaited(_nafahatBridge.queueAzkarNavigation(category));
    }
  }

  static Future<NotificationPermissionState> permissionState() async {
    await init();
    if (!Platform.isAndroid) {
      return const NotificationPermissionState(
        notificationsAllowed: true,
        exactAlarmsAllowed: true,
      );
    }

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final notificationsAllowed =
        await android?.areNotificationsEnabled() ?? true;
    final exactAllowed =
        await android?.canScheduleExactNotifications() ?? true;
    return NotificationPermissionState(
      notificationsAllowed: notificationsAllowed,
      exactAlarmsAllowed: exactAllowed,
    );
  }

  static Future<NotificationPermissionState> requestPermissions() async {
    await init();
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      var notificationsAllowed =
          await android?.areNotificationsEnabled() ?? true;
      if (!notificationsAllowed) {
        notificationsAllowed =
            await android?.requestNotificationsPermission() ?? false;
      }

      var exactAllowed =
          await android?.canScheduleExactNotifications() ?? true;
      if (notificationsAllowed && !exactAllowed) {
        exactAllowed = await android?.requestExactAlarmsPermission() ?? false;
      }
      return NotificationPermissionState(
        notificationsAllowed: notificationsAllowed,
        exactAlarmsAllowed: exactAllowed,
      );
    }

    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final allowed = await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          true;
      return NotificationPermissionState(
        notificationsAllowed: allowed,
        exactAlarmsAllowed: true,
      );
    }

    return const NotificationPermissionState(
      notificationsAllowed: true,
      exactAlarmsAllowed: true,
    );
  }

  static Future<void> syncSchedule(
    List<PrayerDay> days,
    NotificationScheduleConfig config,
  ) async {
    await init();
    await _cancelManagedNotifications();

    final moments = _buildPrayerMoments(days, config.timezone);
    final azkarMoments = _buildAzkarMoments(days, config);
    await _syncNafahatAzkarSchedule(azkarMoments, config);

    final permission = await permissionState();
    if (!permission.notificationsAllowed) {
      await _adhanBridge.cancelPrayerAlarms();
      return;
    }

    final scheduleMode = permission.exactAlarmsAllowed
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    final now = _now(config.timezone);
    final horizon = now.add(Duration(days: Platform.isIOS ? 7 : 31));
    final relevantMoments = moments
        .where((moment) => moment.at.isAfter(now) && moment.at.isBefore(horizon))
        .toList(growable: false);
    final relevantAzkar = azkarMoments
        .where((moment) => moment.at.isAfter(now) && moment.at.isBefore(horizon))
        .toList(growable: false);

    final managedIds = <int>[];

    if (Platform.isAndroid) {
      final nativeAlarms = <AdhanAlarmRequest>[];
      if (config.prayerNotificationsEnabled) {
        var nativeId = _nativeAlarmBaseId;
        for (final moment in relevantMoments) {
          if (!config.enabledPrayers.contains(moment.name)) continue;
          nativeAlarms.add(
            AdhanAlarmRequest(
              id: nativeId++,
              at: moment.at,
              prayer: moment.name,
            ),
          );
        }
      }

      final effectiveVoice = config.silent ? 'None' : config.adhanVoice;
      if (nativeAlarms.isNotEmpty && effectiveVoice != 'None') {
        await _adhanBridge.prepareVoice(effectiveVoice);
      }
      await _adhanBridge.syncPrayerAlarms(
        alarms: nativeAlarms,
        languageCode: config.languageCode,
        voice: effectiveVoice,
        silent: config.silent,
      );
    } else {
      await _adhanBridge.cancelPrayerAlarms();
    }

    var reminderId = _reminderBaseId;
    var fallbackPrayerId = _nativeAlarmBaseId;
    for (final moment in relevantMoments) {
      if (!config.enabledPrayers.contains(moment.name)) continue;

      if (config.prayerNotificationsEnabled && !Platform.isAndroid) {
        final id = fallbackPrayerId++;
        await _schedule(
          id: id,
          title: _prayerTitle(config.languageCode),
          body: _prayerBody(moment.name, config.languageCode),
          at: moment.at,
          channelId: 'prayer_events_v2',
          channelName:
              config.languageCode == 'en' ? 'Prayer times' : 'مواقيت الصلاة',
          silent: config.silent,
          mode: scheduleMode,
        );
        managedIds.add(id);
      }

      if (!config.prayerNotificationsEnabled || !config.remindersEnabled) {
        continue;
      }
      final lead =
          config.reminderMinutes[moment.name] ?? defaultReminderMinutes;
      if (lead <= 0) continue;

      final reminderAt = moment.at.subtract(Duration(minutes: lead));
      if (!reminderAt.isAfter(now)) continue;
      final fullIndex = moments.indexOf(moment);
      if (_conflictsWithPreviousPrayer(moments, fullIndex, reminderAt)) {
        continue;
      }

      final id = reminderId++;
      await _schedule(
        id: id,
        title:
            config.languageCode == 'en' ? 'Prayer reminder' : 'تذكير بالصلاة',
        body: _reminderBody(moment.name, lead, config.languageCode),
        at: reminderAt,
        channelId: _reminderChannelId,
        channelName: config.languageCode == 'en'
            ? 'Prayer reminders'
            : 'تذكيرات الصلاة',
        silent: config.silent,
        mode: scheduleMode,
      );
      managedIds.add(id);
    }

    var azkarId = _azkarBaseId;
    for (final moment in relevantAzkar) {
      final id = azkarId++;
      final morning = moment.category == 'Morning';
      await _schedule(
        id: id,
        title: config.languageCode == 'en'
            ? (morning ? 'Morning adhkar' : 'Evening adhkar')
            : (morning ? 'أذكار الصباح' : 'أذكار المساء'),
        body: config.languageCode == 'en'
            ? 'Open Munib and continue your daily adhkar.'
            : 'افتح منيب وأكمل أذكارك اليومية.',
        at: moment.at,
        channelId: _azkarChannelId,
        channelName:
            config.languageCode == 'en' ? 'Daily adhkar' : 'الأذكار اليومية',
        silent: config.silent,
        mode: scheduleMode,
        payload: 'azkar:${moment.category}',
      );
      managedIds.add(id);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _managedIdsKey,
      managedIds.map((id) => id.toString()).toList(growable: false),
    );
  }

  static bool hasReminderConflict({
    required List<PrayerDay> days,
    required String timezone,
    required String prayer,
    required int minutes,
  }) {
    if (minutes < 1 || minutes > 1440) return true;
    final moments = _buildPrayerMoments(days, timezone);
    for (var i = 0; i < moments.length; i++) {
      final moment = moments[i];
      if (moment.name != prayer) continue;
      final reminderAt = moment.at.subtract(Duration(minutes: minutes));
      if (_conflictsWithPreviousPrayer(moments, i, reminderAt)) return true;
    }
    return false;
  }

  static bool _conflictsWithPreviousPrayer(
    List<_PrayerMoment> moments,
    int index,
    DateTime reminderAt,
  ) {
    if (index <= 0 || index >= moments.length) return false;
    final previous = moments[index - 1];
    return !reminderAt.isAfter(previous.at);
  }

  static Future<void> _syncNafahatAzkarSchedule(
    List<_AzkarMoment> moments,
    NotificationScheduleConfig config,
  ) async {
    final now = _now(config.timezone);
    DateTime? nextMorning;
    DateTime? nextEvening;
    for (final moment in moments) {
      if (!moment.at.isAfter(now)) continue;
      if (moment.category == 'Morning' && nextMorning == null) {
        nextMorning = moment.at;
      }
      if (moment.category == 'Evening' && nextEvening == null) {
        nextEvening = moment.at;
      }
      if (nextMorning != null && nextEvening != null) break;
    }

    await _nafahatBridge.syncAzkarSchedule(
      morningEnabled: config.morningAzkarEnabled,
      morningAt: nextMorning,
      eveningEnabled: config.eveningAzkarEnabled,
      eveningAt: nextEvening,
    );
  }

  static Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
    required String channelId,
    required String channelName,
    required bool silent,
    required AndroidScheduleMode mode,
    String? payload,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.high,
        priority: Priority.high,
        silent: silent,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: DarwinNotificationDetails(presentSound: !silent),
    );

    final zoned = at is tz.TZDateTime
        ? at
        : tz.TZDateTime.from(at, tz.local);
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        zoned,
        details,
        payload: payload,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } on PlatformException {
      if (mode == AndroidScheduleMode.inexactAllowWhileIdle) rethrow;
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        zoned,
        details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  static Future<void> _cancelManagedNotifications() async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_managedIdsKey) ?? const <String>[];
    for (final raw in stored) {
      final id = int.tryParse(raw);
      if (id != null) await _plugin.cancel(id);
    }
    await prefs.remove(_managedIdsKey);
    await _adhanBridge.cancelPrayerAlarms();
  }

  static List<_PrayerMoment> _buildPrayerMoments(
    List<PrayerDay> days,
    String timezone,
  ) {
    final result = <_PrayerMoment>[];
    final location = _location(timezone);

    for (final day in days) {
      final date = DateTime.tryParse(day.date);
      if (date == null) continue;
      final values = <String, String>{
        'Fajr': day.fajr,
        'Dhuhr': day.dhuhr,
        'Asr': day.asr,
        'Maghrib': day.maghrib,
        'Isha': day.isha,
      };
      for (final entry in values.entries) {
        final parsed = _parsePrayerTime(
          date,
          entry.value,
          entry.key,
          location,
        );
        if (parsed != null) {
          result.add(_PrayerMoment(name: entry.key, at: parsed));
        }
      }
    }
    result.sort((a, b) => a.at.compareTo(b.at));
    return result;
  }

  static List<_AzkarMoment> _buildAzkarMoments(
    List<PrayerDay> days,
    NotificationScheduleConfig config,
  ) {
    final result = <_AzkarMoment>[];
    final location = _location(config.timezone);

    for (final day in days) {
      final date = DateTime.tryParse(day.date);
      if (date == null) continue;

      if (config.morningAzkarEnabled) {
        DateTime? at;
        final customMinute = config.morningAzkarMinuteOfDay;
        if (customMinute != null) {
          at = _dateAtMinute(date, customMinute, location);
        } else {
          final fajr = _parsePrayerTime(
            date,
            day.fajr,
            'Fajr',
            location,
          );
          at = fajr?.add(
            const Duration(minutes: defaultMorningAzkarDelayMinutes),
          );
        }
        if (at != null) result.add(_AzkarMoment(category: 'Morning', at: at));
      }

      if (config.eveningAzkarEnabled) {
        final at = _dateAtMinute(
          date,
          config.eveningAzkarMinuteOfDay,
          location,
        );
        result.add(_AzkarMoment(category: 'Evening', at: at));
      }
    }

    result.sort((a, b) => a.at.compareTo(b.at));
    return result;
  }

  static DateTime? _parsePrayerTime(
    DateTime date,
    String raw,
    String prayer,
    tz.Location? location,
  ) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw.trim());
    if (match == null) return null;
    var hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');
    if (hour == null || minute == null || hour > 23 || minute > 59) return null;

    if (const {'Asr', 'Maghrib', 'Isha'}.contains(prayer) && hour < 12) {
      hour += 12;
    }
    if (prayer == 'Dhuhr' && hour < 10) hour += 12;

    return _dateAt(
      date,
      hour,
      minute,
      location,
    );
  }

  static DateTime _dateAtMinute(
    DateTime date,
    int minuteOfDay,
    tz.Location? location,
  ) {
    final safe = minuteOfDay.clamp(0, 1439).toInt();
    return _dateAt(date, safe ~/ 60, safe % 60, location);
  }

  static DateTime _dateAt(
    DateTime date,
    int hour,
    int minute,
    tz.Location? location,
  ) {
    if (location != null) {
      return tz.TZDateTime(
        location,
        date.year,
        date.month,
        date.day,
        hour,
        minute,
      );
    }
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  static tz.Location? _location(String timezone) {
    if (timezone.trim().isEmpty) return null;
    try {
      return tz.getLocation(timezone);
    } catch (_) {
      return null;
    }
  }

  static DateTime _now(String timezone) {
    final location = _location(timezone);
    return location == null ? DateTime.now() : tz.TZDateTime.now(location);
  }

  static String _prayerTitle(String languageCode) =>
      languageCode == 'en' ? 'Prayer time' : 'حان وقت الصلاة';

  static String _prayerBody(String prayer, String languageCode) {
    final localized = _localizedPrayer(prayer, languageCode);
    return languageCode == 'en'
        ? 'It is time for $localized.'
        : 'حان الآن وقت صلاة $localized.';
  }

  static String _reminderBody(
    String prayer,
    int minutes,
    String languageCode,
  ) {
    final localized = _localizedPrayer(prayer, languageCode);
    return languageCode == 'en'
        ? '$minutes minutes until $localized.'
        : 'متبقي $minutes دقيقة على صلاة $localized.';
  }

  static String _localizedPrayer(String prayer, String languageCode) {
    if (languageCode == 'en') return prayer;
    return switch (prayer) {
      'Fajr' => 'الفجر',
      'Dhuhr' => 'الظهر',
      'Asr' => 'العصر',
      'Maghrib' => 'المغرب',
      'Isha' => 'العشاء',
      _ => prayer,
    };
  }
}

class _PrayerMoment {
  final String name;
  final DateTime at;

  const _PrayerMoment({required this.name, required this.at});
}

class _AzkarMoment {
  final String category;
  final DateTime at;

  const _AzkarMoment({required this.category, required this.at});
}
