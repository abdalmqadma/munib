import 'package:flutter/services.dart';

class NafahatBridgeService {
  static const MethodChannel _channel = MethodChannel('com.example.munib/nafahat');

  const NafahatBridgeService();

  Future<void> syncAzkarSchedule({
    required bool morningEnabled,
    required DateTime? morningAt,
    required bool eveningEnabled,
    required DateTime? eveningAt,
  }) async {
    try {
      await _channel.invokeMethod<void>('setAzkarNafahatSchedule', {
        'morningEnabled': morningEnabled,
        'morningAt': morningAt?.millisecondsSinceEpoch ?? 0,
        'eveningEnabled': eveningEnabled,
        'eveningAt': eveningAt?.millisecondsSinceEpoch ?? 0,
      });
    } on MissingPluginException {
      // Nafahat overlays are Android-only. Other platforms safely ignore this sync.
    } on PlatformException {
      // A transient native bridge failure must not block prayer-time updates.
    }
  }

  Future<String?> consumePendingAzkarNavigation() async {
    try {
      final category =
          await _channel.invokeMethod<String>('consumePendingAzkarNavigation');
      return category == 'Morning' || category == 'Evening' ? category : null;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
