import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'presentation/providers/prayer_provider.dart';
import 'presentation/providers/prayer_coach_provider.dart';
import 'presentation/screens/splash_screen.dart';
import 'data/services/notification_service.dart';
import 'data/models/prayer_day.dart';
import 'package:intl/date_symbol_data_local.dart';

// اختبار الكتابة المباشرة من ChatGPT إلى مستودع منيب

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  await initializeDateFormatting('ar', null);
  await dotenv.load(fileName: ".env");
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
    final provider = context.watch<PrayerProvider>();
    
    // ضبط ألوان شريط الحالة (Status Bar) ليتناسب مع الثيم
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: provider.isDarkMode ? Brightness.light : Brightness.dark,
      statusBarBrightness: provider.isDarkMode ? Brightness.dark : Brightness.light,
    ));

    return MaterialApp(
      title: 'Imsakiah AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: provider.isDarkMode ? Brightness.dark : Brightness.light,
        primarySwatch: Colors.blue,
        fontFamily: 'Inter',
        useMaterial3: true,
        scaffoldBackgroundColor: provider.isDarkMode ? const Color(0xFF071019) : const Color(0xFFF5F7FA),
      ),
      home: const SplashScreen(),
    );
  }
}
