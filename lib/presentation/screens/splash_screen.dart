import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_colors.dart';
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
  late final Animation<double> _markProgress;
  late final Animation<double> _wordOpacity;
  late final Animation<Offset> _wordSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1350),
      vsync: this,
    );
    _markProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, .72, curve: Curves.easeOutCubic),
    );
    _wordOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(.28, .88, curve: Curves.easeOut),
    );
    _wordSlide = Tween<Offset>(
      begin: const Offset(0, .16),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(.28, .9, curve: Curves.easeOutCubic),
      ),
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
    final foreground = dark
        ? AppColors.textPrimary
        : AppColors.lightTextPrimary;
    final secondary = dark
        ? AppColors.textSecondary
        : AppColors.lightTextSecondary;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark
                ? const [AppColors.background, AppColors.backgroundDeep]
                : const [
                    AppColors.lightBackground,
                    AppColors.lightBackgroundDeep,
                  ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Semantics(
              image: true,
              label: isArabic ? 'شعار منيب' : 'Munib logo',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 124,
                    height: 124,
                    child: CustomPaint(
                      painter: _MunibMarkPainter(
                        progress: _markProgress,
                        accent: AppColors.gold,
                        foreground: foreground,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  FadeTransition(
                    opacity: _wordOpacity,
                    child: SlideTransition(
                      position: _wordSlide,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'منيب',
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              color: foreground,
                              fontSize: 38,
                              height: 1,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.6,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            isArabic ? 'رفيقك كل يوم' : 'Your daily companion',
                            style: TextStyle(
                              color: secondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: isArabic ? 0 : .6,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: 34,
                            height: 2,
                            decoration: BoxDecoration(
                              color: AppColors.gold,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ],
                      ),
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

class _MunibMarkPainter extends CustomPainter {
  _MunibMarkPainter({
    required this.progress,
    required this.accent,
    required this.foreground,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Color accent;
  final Color foreground;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value.clamp(0.0, 1.0).toDouble();
    final center = Offset(size.width * .48, size.height * .52);
    final radius = size.shortestSide * .315;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    final scale = .82 + (.18 * Curves.easeOutBack.transform(t));
    canvas.scale(scale, scale);
    canvas.translate(-center.dx, -center.dy);

    final haloPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = accent.withValues(alpha: .18 * t);
    canvas.drawCircle(center, radius * 1.22, haloPaint);

    final outer = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    final cutout = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(center.dx + radius * .36, center.dy - radius * .08),
          radius: radius * .82,
        ),
      );
    final crescent = Path.combine(PathOperation.difference, outer, cutout);

    final crescentPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = accent.withValues(alpha: .96 * t);
    canvas.drawPath(crescent, crescentPaint);

    final archPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = foreground.withValues(alpha: .9 * t);
    final arch = Path()
      ..moveTo(center.dx + radius * .11, center.dy + radius * .52)
      ..lineTo(center.dx + radius * .11, center.dy + radius * .08)
      ..quadraticBezierTo(
        center.dx + radius * .28,
        center.dy - radius * .18,
        center.dx + radius * .45,
        center.dy + radius * .08,
      )
      ..lineTo(center.dx + radius * .45, center.dy + radius * .52);
    canvas.drawPath(arch, archPaint);

    final starCenter = Offset(
      center.dx + radius * .82,
      center.dy - radius * .64,
    );
    final star = Path();
    for (var i = 0; i < 8; i++) {
      final angle = -math.pi / 2 + (math.pi / 4 * i);
      final r = i.isEven ? radius * .18 : radius * .075;
      final point = Offset(
        starCenter.dx + math.cos(angle) * r,
        starCenter.dy + math.sin(angle) * r,
      );
      if (i == 0) {
        star.moveTo(point.dx, point.dy);
      } else {
        star.lineTo(point.dx, point.dy);
      }
    }
    star.close();
    canvas.drawPath(
      star,
      Paint()..color = accent.withValues(alpha: t),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MunibMarkPainter oldDelegate) {
    return oldDelegate.accent != accent ||
        oldDelegate.foreground != foreground ||
        oldDelegate.progress != progress;
  }
}
