import 'package:flutter/material.dart';

class AppStrings {
  AppStrings._();

  static const Map<String, Map<String, String>> _values = {
    'ar': {
      'settings': 'الإعدادات',
      'language': 'لغة التطبيق',
      'location': 'المدينة',
      'appearance': 'مظهر التطبيق',
      'dark': 'داكن',
      'light': 'فاتح',
      'rateApp': 'تقييم التطبيق',
      'share': 'مشاركة مع الأصدقاء',
      'version': 'منيب - الإصدار 1.0.0',
      'chooseLanguage': 'اختر اللغة',
      'arabic': 'العربية',
      'english': 'English',
      'home': 'الرئيسية',
      'azkar': 'الأذكار',
      'training': 'التدريب',
      'nextPrayer': 'الصلاة القادمة',
      'todayPrayerTimes': 'مواقيت اليوم',
      'changeImsakia': 'تغيير الإمساكية',
      'noPrayerTimes': 'لا توجد أوقات صلاة',
      'uploadOrLocation': 'ارفع إمساكيتك أو دع منيب يجلبها بناءً على موقعك',
      'fetchCityTimes': 'جلب أوقات مدينتي تلقائياً',
      'uploadImsakia': 'رفع صورة الإمساكية',
      'teachMePrayer': 'علّمني الصلاة',
      'startTraining': 'ابدأ التدريب',
      'notifications': 'الإشعارات',
    },
    'en': {
      'settings': 'Settings',
      'language': 'App Language',
      'location': 'City',
      'appearance': 'Appearance',
      'dark': 'Dark',
      'light': 'Light',
      'rateApp': 'Rate App',
      'share': 'Share with Friends',
      'version': 'Munib - v1.0.0',
      'chooseLanguage': 'Choose Language',
      'arabic': 'العربية',
      'english': 'English',
      'home': 'Home',
      'azkar': 'Adhkar',
      'training': 'Training',
      'nextPrayer': 'Next Prayer',
      'todayPrayerTimes': "Today's Prayer Times",
      'changeImsakia': 'Change Imsakia',
      'noPrayerTimes': 'No prayer times available',
      'uploadOrLocation': 'Upload your Imsakia or let Munib fetch it using your location',
      'fetchCityTimes': 'Fetch my city prayer times',
      'uploadImsakia': 'Upload Imsakia image',
      'teachMePrayer': 'Teach me prayer',
      'startTraining': 'Start Training',
      'notifications': 'Notifications',
    },
  };

  static String text(BuildContext context, String key) {
    final code = Localizations.localeOf(context).languageCode == 'en' ? 'en' : 'ar';
    return _values[code]?[key] ?? _values['ar']?[key] ?? key;
  }
}

extension MunibStrings on BuildContext {
  String tr(String key) => AppStrings.text(this, key);
}
