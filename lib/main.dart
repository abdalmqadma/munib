import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'presentation/providers/prayer_provider.dart';
import 'presentation/providers/prayer_coach_provider.dart';
import 'presentation/screens/splash_screen.dart';
import 'data/services/notification_service.dart';
import 'data/models/prayer_day.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/munib_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await initializeDateFormatting('ar', null);
  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(PrayerDayAdapter());
  }

  await NotificationService.init();

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
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: MunibTheme.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    return MaterialApp(
      title: 'منيب',
      debugShowCheckedModeBanner: false,
      theme: MunibTheme.dark(),
      home: const SplashScreen(),
    );
  }
}
