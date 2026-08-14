class AppLocalization {
  static const Map<String, Map<String, String>> values = {
    'ar': {
      'app_title': 'منيب',
      'next_prayer': 'الصلاة القادمة',
      'remaining': 'المتبقي',
      'fajr': 'الفجر',
      'sunrise': 'الشروق',
      'dhuhr': 'الظهر',
      'asr': 'العصر',
      'maghrib': 'المغرب',
      'isha': 'العشاء',
      'upload_imsakiah': 'رفع الإمساكية',
      'change_imsakiah': 'تغيير الإمساكية',
      'azkar': 'الأذكار',
      'training': 'التدريب',
      'settings': 'الإعدادات',
      'choose_language': 'اختر لغة التطبيق',
      'start_training': 'ابدأ التدريب',
      'coach_desc': 'تعلّم الصلاة خطوة بخطوة مع مدرب ذكي يتابع حركاتك ويساعدك على التحسن.',
      'login': 'تسجيل الدخول',
      'create_account': 'إنشاء حساب جديد',
      'google_sign_in': 'الدخول بواسطة جوجل',
    },
    'en': {
      'app_title': 'Muneeb',
      'next_prayer': 'Next Prayer',
      'remaining': 'Remaining',
      'fajr': 'Fajr',
      'sunrise': 'Sunrise',
      'dhuhr': 'Dhuhr',
      'asr': 'Asr',
      'maghrib': 'Maghrib',
      'isha': 'Isha',
      'upload_imsakiah': 'Upload Imsakiah',
      'change_imsakiah': 'Change Imsakiah',
      'azkar': 'Azkar',
      'training': 'Training',
      'settings': 'Settings',
      'choose_language': 'Choose App Language',
      'start_training': 'Start Training',
      'coach_desc': 'Learn prayer step-by-step with an AI coach tracking your movements.',
      'login': 'Login',
      'create_account': 'Create Account',
      'google_sign_in': 'Sign in with Google',
    }
  };

  static String get(String key, String langCode) {
    return values[langCode]?[key] ?? key;
  }
}
