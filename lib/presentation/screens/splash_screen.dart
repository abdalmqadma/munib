import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/auth_service.dart';
import 'home_screen.dart';
import 'language_selection_screen.dart';
import 'nafahat_intro_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this);
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: const Interval(0, .82, curve: Curves.easeOut));
    _scaleAnimation = Tween<double>(begin: .9, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    await AuthService().signOutUnverifiedPasswordUser();
    final prefs = await SharedPreferences.getInstance();
    final isFirstRun = prefs.getBool('isFirstRun') ?? true;
    final lang = prefs.getString('language');
    final sawNafahatIntro = prefs.getBool('nafahat_intro_v1_seen') ?? false;
    final Widget nextScreen;
    if (lang == null) {
      nextScreen = const LanguageSelectionScreen();
    } else if (isFirstRun) {
      nextScreen = const OnboardingScreen();
    } else if (!sawNafahatIntro) {
      nextScreen = const NafahatIntroScreen();
    } else {
      nextScreen = const HomeScreen();
    }
    if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => nextScreen));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final deviceArabic = ui.PlatformDispatcher.instance.locale.languageCode.toLowerCase() == 'ar';
    final appName = deviceArabic ? 'منيب' : 'Munib';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF07141F) : const Color(0xFFF7F4EE),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 118,
                  height: 118,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0B1F3A) : Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: scheme.primary.withValues(alpha: .22)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? .22 : .08), blurRadius: 28, offset: const Offset(0, 12))],
                  ),
                  child: Center(
                    child: Icon(Icons.nightlight_round, size: 62, color: isDark ? const Color(0xFFF4C76A) : const Color(0xFF1E88E5)),
                  ),
                ),
                const SizedBox(height: 26),
                Text(appName, textDirection: deviceArabic ? TextDirection.rtl : TextDirection.ltr, style: theme.textTheme.displaySmall?.copyWith(fontSize: 48, fontWeight: FontWeight.w900, color: scheme.onSurface)),
                const SizedBox(height: 12),
                Container(width: 44, height: 3, decoration: BoxDecoration(color: const Color(0xFFF4C76A), borderRadius: BorderRadius.circular(99))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
