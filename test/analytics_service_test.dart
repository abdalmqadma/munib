import 'package:flutter_test/flutter_test.dart';
import 'package:munib/data/services/analytics_service.dart';

void main() {
  test('primary tabs map to stable analytics screen names and events', () {
    final home = AnalyticsService.destinationForPrimaryIndex(0)!;
    final adhkar = AnalyticsService.destinationForPrimaryIndex(1)!;
    final nafahat = AnalyticsService.destinationForPrimaryIndex(2)!;
    final settings = AnalyticsService.destinationForPrimaryIndex(3)!;

    expect(home.screenName, 'home');
    expect(
      home.events,
      [
        AnalyticsEventNames.homeView,
        AnalyticsEventNames.prayerTimesView,
      ],
    );
    expect(adhkar.screenName, 'adhkar');
    expect(adhkar.events, [AnalyticsEventNames.adhkarView]);
    expect(nafahat.screenName, 'nafahat');
    expect(nafahat.events, [AnalyticsEventNames.nafahatView]);
    expect(settings.screenName, 'settings');
    expect(settings.events, isEmpty);
  });

  test('unknown primary tab is ignored', () {
    expect(AnalyticsService.destinationForPrimaryIndex(-1), isNull);
    expect(AnalyticsService.destinationForPrimaryIndex(4), isNull);
  });

  test('required custom event names remain stable', () {
    expect(AnalyticsEventNames.homeView, 'home_view');
    expect(AnalyticsEventNames.prayerTimesView, 'prayer_times_view');
    expect(AnalyticsEventNames.adhkarView, 'adhkar_view');
    expect(AnalyticsEventNames.nafahatView, 'nafahat_view');
    expect(AnalyticsEventNames.widgetAdded, 'widget_added');
    expect(AnalyticsEventNames.notificationEnabled, 'notification_enabled');
  });
}
