import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/auth_service.dart';
import '../../data/services/push_notification_service.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, .82, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: .92, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    try {
      await AuthService().signOutUnverifiedPasswordUser();
    } catch (_) {
      // Authentication cleanup is best-effort. Never trap the user on splash.
    }

    final prefs = await SharedPreferences.getInstance();
    final isFirstRun = prefs.getBool('isFirstRun') ?? true;

    final Widget nextScreen;
    final String nextRouteName;
    if (isFirstRun) {
      nextScreen = const OnboardingScreen();
      nextRouteName = '/onboarding';
    } else {
      final pushDestination = PushNotificationService.takeDeferredDestination();
      nextScreen = HomeScreen(
        initialIndex: pushDestination?.homeIndex ?? 0,
        initialAzkarCategory:
            pushDestination?.initialAzkarCategory ?? 'Morning',
      );
      nextRouteName = '/home';
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        settings: RouteSettings(name: nextRouteName),
        builder: (_) => nextScreen,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final dark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Semantics(
              image: true,
              label: isArabic ? 'منيب' : 'Munib',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png',
                    width: 132,
                    height: 132,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isArabic ? 'منيب' : 'Munib',
                    textDirection:
                        isArabic ? TextDirection.rtl : TextDirection.ltr,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: isArabic ? 0 : .3,
                      color: dark
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
