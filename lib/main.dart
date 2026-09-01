import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'core/app_colors.dart';
import 'core/app_theme.dart';
import 'presentation/providers/prayer_provider.dart';
import 'features/settings/presentation/theme_provider.dart';
import 'presentation/screens/splash_screen.dart';
import 'data/services/notification_service.dart';
import 'data/models/prayer_day.dart';

Future<PrayerProvider> _bootstrapPrayerProvider() async {
  final provider = PrayerProvider();
  final deadline = DateTime.now().add(const Duration(seconds: 10));

  // PrayerProvider loads saved locations before it opens the prayers box.
  // Waiting for that box here prevents first-run UI actions from racing the
  // asynchronous bootstrap and having a freshly added location overwritten by
  // an older/empty initialization snapshot.
  while (!Hive.isBoxOpen('prayers')) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('Prayer state initialization timed out');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  // Let the continuation after Hive.openBox publish the loaded state before
  // the first Flutter frame can trigger location actions.
  await Future<void>.delayed(Duration.zero);
  return provider;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('ar', null);
  await initializeDateFormatting('en', null);
  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(PrayerDayAdapter());
  await NotificationService.init();

  final prayerProvider = await _bootstrapPrayerProvider();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => prayerProvider),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const ImsakiahApp(),
    ),
  );
}

class ImsakiahApp extends StatelessWidget {
  const ImsakiahApp({super.key});

  @override
  Widget build(BuildContext context) {
    final prayerProvider = context.watch<PrayerProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final platformDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final effectiveDark = themeProvider.themeMode == ThemeMode.dark ||
        (themeProvider.themeMode == ThemeMode.system && platformDark);

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: effectiveDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: effectiveDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: effectiveDark ? AppColors.backgroundDeep : AppColors.lightBackgroundDeep,
        systemNavigationBarIconBrightness: effectiveDark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: effectiveDark ? AppColors.backgroundDeep : AppColors.lightBackgroundDeep,
      ),
    );

    return MaterialApp(
      title: 'Munib',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeProvider.themeMode,
      locale: prayerProvider.locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supportedLocales) => prayerProvider.locale,
      home: const SplashScreen(),
    );
  }
}
