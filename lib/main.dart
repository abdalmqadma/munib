import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_colors.dart';
import 'core/app_theme.dart';
import 'data/models/prayer_day.dart';
import 'data/services/analytics_service.dart';
import 'data/services/notification_service.dart';
import 'data/services/push_navigation_service.dart';
import 'data/services/push_notification_service.dart';
import 'features/settings/presentation/theme_provider.dart';
import 'firebase_options.dart';
import 'presentation/providers/prayer_provider.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/widgets/analytics_app_tracker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  PushNotificationService.registerBackgroundHandler();
  await initializeDateFormatting('ar', null);
  await initializeDateFormatting('en', null);
  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(PrayerDayAdapter());
  await NotificationService.init();
  await PushNotificationService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PrayerProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const AnalyticsAppTracker(child: ImsakiahApp()),
    ),
  );
}

class ImsakiahApp extends StatefulWidget {
  const ImsakiahApp({super.key});

  @override
  State<ImsakiahApp> createState() => _ImsakiahAppState();
}

class _ImsakiahAppState extends State<ImsakiahApp> {
  static final _analyticsObserver = MunibAnalyticsObserver();

  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  StreamSubscription<PushMessage>? _foregroundPushSubscription;
  StreamSubscription<PushDestination>? _openedPushSubscription;

  @override
  void initState() {
    super.initState();
    _foregroundPushSubscription =
        PushNotificationService.foregroundMessages.listen(_showForegroundPush);
    _openedPushSubscription =
        PushNotificationService.openedDestinations.listen(_openPushDestination);
  }

  @override
  void dispose() {
    _foregroundPushSubscription?.cancel();
    _openedPushSubscription?.cancel();
    super.dispose();
  }

  void _showForegroundPush(PushMessage message) {
    if (!mounted) return;
    final messenger = _messengerKey.currentState;
    if (messenger == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showForegroundPush(message);
      });
      return;
    }

    final isEnglish = context.read<PrayerProvider>().isEnglish;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.title.isNotEmpty)
              Text(
                message.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            if (message.title.isNotEmpty && message.body.isNotEmpty)
              const SizedBox(height: 4),
            if (message.body.isNotEmpty) Text(message.body),
          ],
        ),
        action: message.destination == null
            ? null
            : SnackBarAction(
                label: isEnglish ? 'Open' : 'فتح',
                onPressed: () => _openPushDestination(message.destination!),
              ),
      ),
    );
  }

  Future<void> _openPushDestination(PushDestination destination) async {
    final prefs = await SharedPreferences.getInstance();
    final languageSelected = prefs.getString('language') != null;
    final onboardingDone = !(prefs.getBool('isFirstRun') ?? true);

    if (!languageSelected || !onboardingDone) {
      PushNotificationService.deferDestination(destination);
      return;
    }

    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      PushNotificationService.deferDestination(destination);
      return;
    }

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/home'),
        builder: (_) => HomeScreen(
          initialIndex: destination.homeIndex,
          initialAzkarCategory: destination.initialAzkarCategory,
        ),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final prayerProvider = context.watch<PrayerProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final platformDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final effectiveDark = themeProvider.themeMode == ThemeMode.dark ||
        (themeProvider.themeMode == ThemeMode.system && platformDark);

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            effectiveDark ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            effectiveDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: effectiveDark
            ? AppColors.backgroundDeep
            : AppColors.lightBackgroundDeep,
        systemNavigationBarIconBrightness:
            effectiveDark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: effectiveDark
            ? AppColors.backgroundDeep
            : AppColors.lightBackgroundDeep,
      ),
    );

    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
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
      navigatorObservers: [_analyticsObserver],
      home: const SplashScreen(),
    );
  }
}
