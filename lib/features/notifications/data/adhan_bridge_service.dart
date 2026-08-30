import 'package:flutter/services.dart';

class AdhanAlarmRequest {
  final int id;
  final DateTime at;
  final String prayer;

  const AdhanAlarmRequest({
    required this.id,
    required this.at,
    required this.prayer,
  });

  Map<String, Object> toMap() => {
        'id': id,
        'at': at.millisecondsSinceEpoch,
        'prayer': prayer,
      };
}

class AdhanBridgeService {
  static const MethodChannel _channel =
      MethodChannel('com.example.munib/adhan');

  const AdhanBridgeService();

  Future<void> prepareVoice(String voice) async {
    if (voice == 'None') return;
    try {
      await _channel.invokeMethod<void>('prepareAdhanVoice', {'voice': voice});
    } on MissingPluginException {
      // Android-only feature. Other platforms keep notification scheduling.
    } on PlatformException {
      // Audio preparation is best-effort; the prayer notification still works.
    }
  }

  Future<void> syncPrayerAlarms({
    required List<AdhanAlarmRequest> alarms,
    required String languageCode,
    required String voice,
    required bool silent,
  }) async {
    try {
      await _channel.invokeMethod<void>('syncPrayerAlarms', {
        'alarms': alarms.map((alarm) => alarm.toMap()).toList(),
        'languageCode': languageCode == 'en' ? 'en' : 'ar',
        'voice': voice,
        'silent': silent,
      });
    } on MissingPluginException {
      // Native prayer alarms are Android-only.
    } on PlatformException {
      // Flutter notifications remain available as the non-native fallback.
    }
  }

  Future<void> cancelPrayerAlarms() async {
    try {
      await _channel.invokeMethod<void>('cancelPrayerAlarms');
    } on MissingPluginException {
      // Android-only.
    } on PlatformException {
      // A stale native alarm is also cleared on the next successful sync.
    }
  }
}
