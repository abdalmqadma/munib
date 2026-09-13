import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late final Future<Uint8List> _darkLogoBytes;
  late final Future<Uint8List> _lightLogoBytes;

  @override
  void initState() {
    super.initState();
    _darkLogoBytes = _loadLogo(
      'assets/muneeb_icons/munib_splash_dark.png.b64',
    );
    _lightLogoBytes = _loadLogo(
      'assets/muneeb_icons/munib_splash_light.png.b64',
    );
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

  Future<Uint8List> _loadLogo(String assetPath) async {
    final encoded = await rootBundle.loadString(assetPath);
    return base64Decode(encoded.trim());
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
              child: SizedBox(
                width: 256,
                height: 256,
                child: FutureBuilder<Uint8List>(
                  future: dark ? _darkLogoBytes : _lightLogoBytes,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Image.memory(
                        snapshot.data!,
                        width: 256,
                        height: 256,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        gaplessPlayback: true,
                      );
                    }

                    if (snapshot.hasError) {
                      return Image.asset(
                        'android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png',
                        width: 132,
                        height: 132,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
