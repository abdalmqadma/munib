import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/auth_service.dart';
import 'home_screen.dart';
import 'language_selection_screen.dart';
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
    _scaleAnimation = Tween<double>(begin: .9, end: 1).animate(
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
      // Authentication cleanup is best-effort. Never trap the user on splash
      // because Firebase or the network is temporarily unavailable.
    }

    final prefs = await SharedPreferences.getInstance();
    final isFirstRun = prefs.getBool('isFirstRun') ?? true;
    final lang = prefs.getString('language');

    final Widget nextScreen;
    if (lang == null) {
      nextScreen = const LanguageSelectionScreen();
    } else if (isFirstRun) {
      nextScreen = const OnboardingScreen();
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
    final dark = theme.brightness == Brightness.dark;
    final markColor = dark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Semantics(
              image: true,
              label: 'Munib',
              child: SizedBox.square(
                dimension: 132,
                child: CustomPaint(
                  painter: _MunibVectorPainter(color: markColor),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MunibVectorPainter extends CustomPainter {
  final Color color;

  const _MunibVectorPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final center = Offset(size.width * .49, size.height * .49);
    final outerRadius = size.shortestSide * .35;
    final crescent = Path()
      ..addOval(Rect.fromCircle(center: center, radius: outerRadius));
    final cutout = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(size.width * .59, size.height * .41),
          radius: outerRadius * .82,
        ),
      );
    final crescentPath = Path.combine(PathOperation.difference, crescent, cutout);
    canvas.drawPath(crescentPath, paint);

    final starCenter = Offset(size.width * .72, size.height * .28);
    final star = Path();
    const points = 8;
    for (var i = 0; i < points; i++) {
      final angle = i * 3.141592653589793 / 4;
      final radius = i.isEven ? size.width * .065 : size.width * .025;
      final point = Offset(
        starCenter.dx + radius * _cos(angle),
        starCenter.dy + radius * _sin(angle),
      );
      if (i == 0) {
        star.moveTo(point.dx, point.dy);
      } else {
        star.lineTo(point.dx, point.dy);
      }
    }
    star.close();
    canvas.drawPath(star, paint);
  }

  double _sin(double x) {
    // The painter only uses multiples of 45 degrees; this avoids another
    // dependency while keeping the mark deterministic.
    const values = [
      0.0,
      .70710678,
      1.0,
      .70710678,
      0.0,
      -.70710678,
      -1.0,
      -.70710678,
    ];
    return values[((x / (3.141592653589793 / 4)).round()) % 8];
  }

  double _cos(double x) {
    const values = [
      1.0,
      .70710678,
      0.0,
      -.70710678,
      -1.0,
      -.70710678,
      0.0,
      .70710678,
    ];
    return values[((x / (3.141592653589793 / 4)).round()) % 8];
  }

  @override
  bool shouldRepaint(covariant _MunibVectorPainter oldDelegate) =>
      oldDelegate.color != color;
}
