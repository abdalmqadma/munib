import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'core/app_colors.dart';
import 'core/app_theme.dart';
import 'presentation/providers/prayer_provider.dart';
import 'presentation/providers/prayer_coach_provider.dart';
import 'presentation/screens/splash_screen.dart';
import 'data/services/notification_service.dart';
import 'data/models/prayer_day.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await initializeDateFormatting('ar', null);
  await dotenv.load(fileName: '.env');
  await Hive.initFlutter();

  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(PrayerDayAdapter());
  }

  await NotificationService.init();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.backgroundDeep,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: AppColors.backgroundDeep,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PrayerProvider()),
        ChangeNotifierProvider(create: (_) => PrayerCoachProvider()),
      ],
      child: const ImsakiahApp(),
    ),
  );
}

class ImsakiahApp extends StatelessWidget {
  const ImsakiahApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Munib',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      home: const SplashScreen(),
    );
  }
}
