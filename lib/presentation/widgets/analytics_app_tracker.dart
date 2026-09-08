import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/analytics_service.dart';
import '../../data/services/notification_service.dart';
import '../providers/prayer_provider.dart';

class AnalyticsAppTracker extends StatefulWidget {
  final Widget child;

  const AnalyticsAppTracker({
    super.key,
    required this.child,
  });

  @override
  State<AnalyticsAppTracker> createState() => _AnalyticsAppTrackerState();
}

class _AnalyticsAppTrackerState extends State<AnalyticsAppTracker>
    with WidgetsBindingObserver {
  static const _widgetCountKey = 'analytics_installed_widget_count_v1';

  PrayerProvider? _prayerProvider;
  bool _notificationBaselineReady = false;
  bool _notificationBaselineRequested = false;
  bool _checkingWidgets = false;
  bool? _notificationsAllowed;
  bool _prayerNotif = false;
  bool _reminderNotif = false;
  bool _morningAzkarNotif = false;
  bool _eveningAzkarNotif = false;
  int? _lastPrimaryIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_syncInstalledWidgetCount());
      unawaited(_syncNotificationPermissionState(establishBaseline: true));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<PrayerProvider>();
    if (!identical(provider, _prayerProvider)) {
      _prayerProvider?.removeListener(_handlePrayerProviderChanged);
      _prayerProvider = provider;
      provider.addListener(_handlePrayerProviderChanged);
    }

    if (!_notificationBaselineRequested) {
      _notificationBaselineRequested = true;
      unawaited(_loadNotificationFeatureBaseline());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_syncInstalledWidgetCount());
    unawaited(_syncNotificationPermissionState());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _prayerProvider?.removeListener(_handlePrayerProviderChanged);
    super.dispose();
  }

  Future<void> _loadNotificationFeatureBaseline() async {
    final prefs = await SharedPreferences.getInstance();
    _prayerNotif = prefs.getBool('prayerNotif') ?? true;
    _reminderNotif = prefs.getBool('reminderNotif') ?? true;
    final legacyAzkar = prefs.getBool('azkarNotif') ?? false;
    _morningAzkarNotif =
        prefs.getBool('morningAzkarNotif') ?? legacyAzkar;
    _eveningAzkarNotif =
        prefs.getBool('eveningAzkarNotif') ?? legacyAzkar;
    _notificationBaselineReady = true;
  }

  void _handlePrayerProviderChanged() {
    if (!_notificationBaselineReady) return;
    final provider = _prayerProvider;
    if (provider == null) return;

    _trackNotificationTransition('prayer', _prayerNotif, provider.prayerNotif);
    _trackNotificationTransition(
      'prayer_reminder',
      _reminderNotif,
      provider.reminderNotif,
    );
    _trackNotificationTransition(
      'morning_adhkar',
      _morningAzkarNotif,
      provider.morningAzkarNotif,
    );
    _trackNotificationTransition(
      'evening_adhkar',
      _eveningAzkarNotif,
      provider.eveningAzkarNotif,
    );

    _prayerNotif = provider.prayerNotif;
    _reminderNotif = provider.reminderNotif;
    _morningAzkarNotif = provider.morningAzkarNotif;
    _eveningAzkarNotif = provider.eveningAzkarNotif;
  }

  void _trackNotificationTransition(String type, bool previous, bool current) {
    if (previous || !current) return;
    unawaited(_logNotificationEnabledIfAllowed(type));
  }

  Future<void> _logNotificationEnabledIfAllowed(String type) async {
    final state = await NotificationService.permissionState();
    _notificationsAllowed = state.notificationsAllowed;
    if (!state.notificationsAllowed) return;
    await AnalyticsService.logNotificationEnabled(type);
  }

  Future<void> _syncNotificationPermissionState({
    bool establishBaseline = false,
  }) async {
    try {
      final state = await NotificationService.permissionState();
      final current = state.notificationsAllowed;
      final previous = _notificationsAllowed;
      _notificationsAllowed = current;

      if (establishBaseline || previous == null || previous || !current) return;
      if (!_anyNotificationFeatureEnabled) return;
      await AnalyticsService.logNotificationEnabled('system_permission');
    } catch (_) {
      // Analytics must never affect notification behavior.
    }
  }

  bool get _anyNotificationFeatureEnabled =>
      _prayerNotif ||
      _reminderNotif ||
      _morningAzkarNotif ||
      _eveningAzkarNotif;

  Future<void> _syncInstalledWidgetCount() async {
    if (_checkingWidgets) return;
    _checkingWidgets = true;
    try {
      final widgets = await HomeWidget.getInstalledWidgets();
      final currentCount = widgets.length;
      final prefs = await SharedPreferences.getInstance();
      final previousCount = prefs.getInt(_widgetCountKey);

      if (previousCount != null && currentCount > previousCount) {
        await AnalyticsService.logWidgetAdded(
          addedCount: currentCount - previousCount,
          installedCount: currentCount,
        );
      }
      await prefs.setInt(_widgetCountKey, currentCount);
    } catch (_) {
      // Widget analytics is best-effort and must not affect widget behavior.
    } finally {
      _checkingWidgets = false;
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is! ScrollEndNotification) return false;
    final metrics = notification.metrics;
    if (metrics is! PageMetrics || metrics.viewportDimension <= 0) return false;

    final pageCount =
        (metrics.maxScrollExtent / metrics.viewportDimension).round() + 1;
    if (pageCount != 4) return false;

    final index = (metrics.pixels / metrics.viewportDimension)
        .round()
        .clamp(0, 3)
        .toInt();
    if (_lastPrimaryIndex == index) return false;
    _lastPrimaryIndex = index;
    unawaited(AnalyticsService.trackPrimaryIndex(index));
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: widget.child,
    );
  }
}
