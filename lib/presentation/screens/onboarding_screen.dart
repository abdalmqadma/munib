import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/prayer_provider.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstRun', false);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isEn = context.watch<PrayerProvider>().isEnglish;

    final pages = [
      _OnboardingPage(
        icon: Icons.document_scanner_outlined,
        title: isEn ? 'Munib reads your Imsakia' : 'الذكاء الاصطناعي يقرأ إمساكيتك',
        body: isEn
            ? 'Upload a clear Imsakia image and Munib will extract prayer times for you.'
            : 'ارفع صورة واضحة للإمساكية وسيستخرج منيب أوقات الصلاة تلقائياً.',
      ),
      _OnboardingPage(
        icon: Icons.widgets_outlined,
        title: isEn ? 'Prayer times at a glance' : 'مواقيت الصلاة أمامك دائماً',
        body: isEn
            ? 'Keep the next prayer and countdown easy to reach from the app and widget.'
            : 'تابع الصلاة القادمة والعد التنازلي بسهولة من التطبيق والويدجت.',
      ),
      _OnboardingPage(
        icon: Icons.auto_awesome_rounded,
        title: isEn ? 'A calmer daily routine' : 'روتين يومي أبسط',
        body: isEn
            ? 'Use adhkar and Nafahat alongside your prayer times to keep useful reminders close throughout the day.'
            : 'استخدم الأذكار ونفحات بجانب مواقيت الصلاة لتبقى التذكيرات المفيدة قريبة منك خلال اليوم.',
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(isEn ? 'Skip' : 'تخطي'),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: pages,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: index == _currentPage ? 26 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: index == _currentPage
                              ? scheme.primary
                              : scheme.onSurface.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        if (_currentPage < pages.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                          );
                        } else {
                          _finish();
                        }
                      },
                      child: Text(
                        _currentPage == pages.length - 1
                            ? (isEn ? 'Get started' : 'ابدأ الآن')
                            : (isEn ? 'Next' : 'التالي'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(42),
              border: Border.all(color: scheme.outline),
            ),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 58, color: scheme.primary),
              ),
            ),
          ),
          const SizedBox(height: 48),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }
}
