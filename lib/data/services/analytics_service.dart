import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class AnalyticsEventNames {
  const AnalyticsEventNames._();

  static const homeView = 'home_view';
  static const prayerTimesView = 'prayer_times_view';
  static const adhkarView = 'adhkar_view';
  static const nafahatView = 'nafahat_view';
  static const widgetAdded = 'widget_added';
  static const notificationEnabled = 'notification_enabled';
}

class AnalyticsDestination {
  final String screenName;
  final String screenClass;
  final List<String> events;

  const AnalyticsDestination({
    required this.screenName,
    required this.screenClass,
    this.events = const [],
  });
}

class AnalyticsService {
  const AnalyticsService._();

  static FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  static AnalyticsDestination? destinationForPrimaryIndex(int index) {
    return switch (index) {
      0 => const AnalyticsDestination(
          screenName: 'home',
          screenClass: 'HomeScreen',
          events: [
            AnalyticsEventNames.homeView,
            AnalyticsEventNames.prayerTimesView,
          ],
        ),
      1 => const AnalyticsDestination(
          screenName: 'adhkar',
          screenClass: 'AzkarScreen',
          events: [AnalyticsEventNames.adhkarView],
        ),
      2 => const AnalyticsDestination(
          screenName: 'nafahat',
          screenClass: 'WidgetPreviewScreen',
          events: [AnalyticsEventNames.nafahatView],
        ),
      3 => const AnalyticsDestination(
          screenName: 'settings',
          screenClass: 'SettingsScreen',
        ),
      _ => null,
    };
  }

  static Future<void> trackPrimaryIndex(int index) async {
    final destination = destinationForPrimaryIndex(index);
    if (destination == null) return;

    await logScreenView(
      screenName: destination.screenName,
      screenClass: destination.screenClass,
    );
    for (final event in destination.events) {
      await logEvent(event);
    }
  }

  static Future<void> logScreenView({
    required String screenName,
    required String screenClass,
  }) {
    return _safe(() => _analytics.logEvent(
          name: 'screen_view',
          parameters: {
            'firebase_screen': screenName,
            'firebase_screen_class': screenClass,
          },
        ));
  }

  static Future<void> logEvent(
    String name, {
    Map<String, Object>? parameters,
  }) {
    return _safe(() => _analytics.logEvent(
          name: name,
          parameters: parameters,
        ));
  }

  static Future<void> logWidgetAdded({
    required int addedCount,
    required int installedCount,
  }) {
    return logEvent(
      AnalyticsEventNames.widgetAdded,
      parameters: {
        'added_count': addedCount,
        'installed_count': installedCount,
      },
    );
  }

  static Future<void> logNotificationEnabled(String type) {
    return logEvent(
      AnalyticsEventNames.notificationEnabled,
      parameters: {'notification_type': type},
    );
  }

  static Future<void> _safe(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (error) {
      debugPrint('Analytics event skipped: $error');
    }
  }
}

class MunibAnalyticsObserver extends NavigatorObserver {
  void _track(Route<dynamic>? route) {
    if (route is! PageRoute<dynamic>) return;

    final routeName = route.settings.name;
    final screen = switch (routeName) {
      '/' || '/splash' => const AnalyticsDestination(
          screenName: 'splash',
          screenClass: 'SplashScreen',
        ),
      '/language' => const AnalyticsDestination(
          screenName: 'language_selection',
          screenClass: 'LanguageSelectionScreen',
        ),
      '/onboarding' => const AnalyticsDestination(
          screenName: 'onboarding',
          screenClass: 'OnboardingScreen',
        ),
      '/home' => AnalyticsService.destinationForPrimaryIndex(0),
      _ => null,
    };

    if (screen == null) return;
    if (routeName == '/home') {
      unawaited(AnalyticsService.trackPrimaryIndex(0));
      return;
    }

    unawaited(
      AnalyticsService.logScreenView(
        screenName: screen.screenName,
        screenClass: screen.screenClass,
      ),
    );
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _track(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _track(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _track(previousRoute);
  }
}
