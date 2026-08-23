import 'package:home_widget/home_widget.dart';
import 'package:flutter/foundation.dart';

class WidgetService {
  static Future<void> updateWidget({
    required String currentTime,
    required String nextPrayer,
    required String timeLeft,
    required DateTime? nextPrayerTime,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('current_time', currentTime);
      await HomeWidget.saveWidgetData<String>('next_prayer', nextPrayer);
      await HomeWidget.saveWidgetData<String>('time_left', timeLeft);
      await HomeWidget.saveWidgetData<int>(
        'next_prayer_epoch_ms',
        nextPrayerTime?.millisecondsSinceEpoch ?? 0,
      );

      await HomeWidget.updateWidget(name: 'PrayerWidgetSmall', androidName: 'PrayerWidgetSmall');
      await HomeWidget.updateWidget(name: 'PrayerWidgetMedium', androidName: 'PrayerWidgetMedium');
      await HomeWidget.updateWidget(name: 'PrayerWidgetLarge', androidName: 'PrayerWidgetLarge');
    } catch (e) {
      debugPrint('Error updating widgets: $e');
    }
  }
}
