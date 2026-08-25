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

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1350),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, .82, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: .88, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
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

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => nextScreen),
      );
    }
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

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.surface,
              scheme.surface,
              scheme.primary.withValues(alpha: .055),
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 132,
                    height: 132,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(34),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: .28),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 30,
                          offset: Offset(0, 14),
                          color: Color(0x28000000),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(27),
                      child: Image.asset(
                        'assets/muneeb_icons/store/playstore_512.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'منيب',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontSize: 54,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'M U N E E B',
                    style: theme.textTheme.labelMedium?.copyWith(
                      letterSpacing: 7,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: 42,
                    height: 3,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: .55),
                      borderRadius: BorderRadius.circular(99),
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
