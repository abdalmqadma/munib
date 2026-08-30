import 'package:flutter/services.dart';

class NafahatBridgeService {
  static const MethodChannel _channel = MethodChannel('com.example.munib/nafahat');
  static String? _queuedCategory;

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

  Future<void> queueAzkarNavigation(String category) async {
    final normalized = _normalizeCategory(category);
    if (normalized == null) return;
    _queuedCategory = normalized;
    try {
      await _channel.invokeMethod<void>('queueAzkarNavigation', {
        'category': normalized,
      });
    } on MissingPluginException {
      // The in-memory queue still handles non-Android notification callbacks.
    } on PlatformException {
      // Keep the local queue as a safe fallback if the native channel is busy.
    }
  }

  Future<String?> consumePendingAzkarNavigation() async {
    final localCategory = _queuedCategory;
    _queuedCategory = null;
    if (localCategory != null) return localCategory;

    try {
      final category =
          await _channel.invokeMethod<String>('consumePendingAzkarNavigation');
      return _normalizeCategory(category);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static String? _normalizeCategory(String? category) {
    if (category == 'Morning' || category == 'Evening') return category;
    return null;
  }
}
