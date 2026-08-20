import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/munib_theme.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  static const _pages = [
    _OnboardingData(
      icon: Icons.document_scanner_outlined,
      title: 'إمساكيتك تصبح ذكية',
      body: 'ارفع صورة الإمساكية، ومنيب يستخرج المواقيت ويرتبها لك تلقائياً.',
    ),
    _OnboardingData(
      icon: Icons.schedule_rounded,
      title: 'الصلاة التالية أمامك دائماً',
      body: 'تابع الصلاة القادمة والعد التنازلي ومواقيت اليوم من شاشة واحدة هادئة.',
    ),
    _OnboardingData(
      icon: Icons.auto_awesome_outlined,
      title: 'رفيق يومي بسيط وهادئ',
      body: 'أذكار، تنبيهات، وميزات منيب في تجربة واحدة بدون تعقيد.',
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingDone', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF122B39), MunibTheme.background],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _finish,
                      child: const Text(
                        'تخطي',
                        style: TextStyle(color: MunibTheme.textSecondary),
                      ),
                    ),
                    const Text(
                      'منيب',
                      style: TextStyle(
                        color: MunibTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (_, i) => _OnboardingPage(data: _pages[i]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 7,
                          width: i == _index ? 28 : 7,
                          decoration: BoxDecoration(
                            color: i == _index
                                ? MunibTheme.gold
                                : const Color(0x33495D69),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_index == _pages.length - 1) {
                            _finish();
                          } else {
                            _controller.nextPage(
                              duration: const Duration(milliseconds: 320),
                              curve: Curves.easeOutCubic,
                            );
                          }
                        },
                        child: Text(
                          _index == _pages.length - 1 ? 'ابدأ مع منيب' : 'التالي',
                          style: const TextStyle(fontSize: 17),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingData data;
  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(48),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF21475B), Color(0xFF142B38)],
              ),
              border: Border.all(color: const Color(0x334F6B7B)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 30,
                  offset: Offset(0, 18),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 98,
                height: 98,
                decoration: BoxDecoration(
                  color: const Color(0x22D9A85A),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x55D9A85A)),
                ),
                child: Icon(data.icon, size: 44, color: MunibTheme.gold),
              ),
            ),
          ),
          const SizedBox(height: 54),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MunibTheme.textPrimary,
              fontSize: 29,
              height: 1.35,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            data.body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MunibTheme.textSecondary,
              fontSize: 16,
              height: 1.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingData {
  final IconData icon;
  final String title;
  final String body;
  const _OnboardingData({
    required this.icon,
    required this.title,
    required this.body,
  });
}
