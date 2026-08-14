import 'package:home_widget/home_widget.dart';
import 'package:flutter/foundation.dart';

class WidgetService {
  static Future<void> updateWidget({
    required String currentTime,
    required String nextPrayer,
    required String timeLeft,
  }) async {
    try {
      // Save data for all widgets
      await HomeWidget.saveWidgetData<String>('current_time', currentTime);
      await HomeWidget.saveWidgetData<String>('next_prayer', nextPrayer);
      await HomeWidget.saveWidgetData<String>('time_left', timeLeft);
      
      // Notify all 3 widget providers explicitly
      await HomeWidget.updateWidget(name: 'PrayerWidgetSmall', androidName: 'PrayerWidgetSmall');
      await HomeWidget.updateWidget(name: 'PrayerWidgetMedium', androidName: 'PrayerWidgetMedium');
      await HomeWidget.updateWidget(name: 'PrayerWidgetLarge', androidName: 'PrayerWidgetLarge');
    } catch (e) {
      debugPrint("Error updating widgets: $e");
    }
  }
}
