import 'dart:math' as math;

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

enum AppUpdateType { none, optional, force }

class AppUpdateDecision {
  final AppUpdateType type;
  final int currentBuild;
  final int latestBuild;
  final int minimumBuild;
  final String updateUrl;
  final String message;

  const AppUpdateDecision({
    required this.type,
    required this.currentBuild,
    required this.latestBuild,
    required this.minimumBuild,
    required this.updateUrl,
    required this.message,
  });

  bool get shouldShow => type != AppUpdateType.none;
  bool get isForce => type == AppUpdateType.force;
}

AppUpdateType evaluateAppUpdate({
  required int currentBuild,
  required int latestBuild,
  required int minimumBuild,
}) {
  if (currentBuild <= 0) return AppUpdateType.none;

  final safeMinimum = math.max(0, minimumBuild);
  final safeLatest = math.max(safeMinimum, latestBuild);

  if (currentBuild < safeMinimum) return AppUpdateType.force;
  if (currentBuild < safeLatest) return AppUpdateType.optional;
  return AppUpdateType.none;
}

class AppUpdateService {
  const AppUpdateService._();

  static const _latestBuildKey = 'android_latest_build';
  static const _minimumBuildKey = 'android_minimum_build';
  static const _updateUrlKey = 'android_update_url';
  static const _updateMessageKey = 'android_update_message';

  static const _defaultUpdateUrl =
      'https://github.com/abdalmqadma/munib/releases/latest';
  static const _defaultUpdateMessage =
      'يتوفر تحديث جديد لمنيب. / A new Munib update is available.';

  static bool _checkedThisSession = false;

  static Future<AppUpdateDecision> checkForUpdate() async {
    if (_checkedThisSession ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return _noUpdate();
    }
    _checkedThisSession = true;

    final remoteConfig = FirebaseRemoteConfig.instance;

    try {
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval:
              kDebugMode ? Duration.zero : const Duration(hours: 1),
        ),
      );
      await remoteConfig.setDefaults(const {
        _latestBuildKey: 1,
        _minimumBuildKey: 1,
        _updateUrlKey: _defaultUpdateUrl,
        _updateMessageKey: _defaultUpdateMessage,
      });

      try {
        await remoteConfig.fetchAndActivate();
      } catch (error) {
        // Keep using the last activated values (or safe in-app defaults).
        // An unavailable Remote Config backend must never block Munib startup.
        debugPrint('Remote Config update check deferred: $error');
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(packageInfo.buildNumber.trim()) ?? 0;
      if (currentBuild <= 0) return _noUpdate();

      final minimumBuild = remoteConfig.getInt(_minimumBuildKey);
      final latestBuild = math.max(
        minimumBuild,
        remoteConfig.getInt(_latestBuildKey),
      );
      final updateUrl = remoteConfig.getString(_updateUrlKey).trim();
      final message = remoteConfig.getString(_updateMessageKey).trim();

      return AppUpdateDecision(
        type: evaluateAppUpdate(
          currentBuild: currentBuild,
          latestBuild: latestBuild,
          minimumBuild: minimumBuild,
        ),
        currentBuild: currentBuild,
        latestBuild: latestBuild,
        minimumBuild: minimumBuild,
        updateUrl: updateUrl.isEmpty ? _defaultUpdateUrl : updateUrl,
        message: message.isEmpty ? _defaultUpdateMessage : message,
      );
    } catch (error) {
      debugPrint('App update check skipped: $error');
      return _noUpdate();
    }
  }

  static Future<bool> openUpdateUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      return false;
    }

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error) {
      debugPrint('Unable to open update URL: $error');
      return false;
    }
  }

  static AppUpdateDecision _noUpdate() => const AppUpdateDecision(
        type: AppUpdateType.none,
        currentBuild: 0,
        latestBuild: 0,
        minimumBuild: 0,
        updateUrl: _defaultUpdateUrl,
        message: _defaultUpdateMessage,
      );
}
