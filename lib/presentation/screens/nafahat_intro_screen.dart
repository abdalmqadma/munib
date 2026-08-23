import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_colors.dart';
import 'home_screen.dart';

class NafahatIntroScreen extends StatelessWidget {
  const NafahatIntroScreen({super.key});

  Future<void> _finish(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('nafahat_intro_v1_seen', true);
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen(initialIndex: 2)),
    );
  }

  Future<void> _later(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('nafahat_intro_v1_seen', true);
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    String t(String ar, String en) => isArabic ? ar : en;

    return Scaffold(
      body: DecoratedBox(
        decoration: theme.brightness == Brightness.dark
            ? const BoxDecoration(gradient: AppColors.appBackgroundGradient)
            : BoxDecoration(color: scheme.surface),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              children: [
                const Spacer(),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 154,
                      height: 154,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primary.withValues(alpha: .08),
                      ),
                    ),
                    Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0B1F3A), Color(0xFF1E88E5)],
                        ),
                        border: Border.all(color: const Color(0xFFF4C76A), width: 3),
                        boxShadow: const [
                          BoxShadow(blurRadius: 30, offset: Offset(0, 12), color: Color(0x33000000)),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFFF4C76A),
                        size: 42,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 34),
                Text(
                  t('جديد في منيب — نفحات', 'New in Muneeb — Nafahat'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                Text(
                  t(
                    'نفحة قصيرة تظهر فوق التطبيقات في موعدك ثم تختفي. افتحها لآية بتفسير مختصر، حديث مع فائدته ومصدره، ذكر مع فضله أو أثر طيب. ويمكن لمنيب اختيار محتوى أنسب للصباح والمساء والجمعة وقرب الصلاة.',
                    'A short reflection appears above other apps on your schedule, then disappears. Open it for a verse with short tafsir, hadith with benefit and source, adhkar with virtue, or a gentle reflection. Muneeb can also prioritize content for mornings, evenings, Friday and when prayer is near.',
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant, height: 1.65),
                ),
                const SizedBox(height: 28),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: .88),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: scheme.outline),
                  ),
                  child: Column(
                    children: [
                      _Benefit(
                        icon: Icons.schedule_rounded,
                        text: t('أنت تحدد كل كم تظهر وكم ثانية تبقى', 'You choose how often it appears and how long it stays'),
                      ),
                      const SizedBox(height: 14),
                      _Benefit(
                        icon: Icons.swipe_rounded,
                        text: t('تلتصق بأقرب حافة يمين أو شمال بعيداً عن أزرار النظام', 'It snaps to the nearest left or right edge away from system controls'),
                      ),
                      const SizedBox(height: 14),
                      _Benefit(
                        icon: Icons.delete_outline_rounded,
                        text: t('اسحبها إلى دائرة × بالأسفل لإخفائها حتى الموعد القادم فقط', 'Drag it to the × target below to hide it only until the next scheduled reflection'),
                      ),
                      const SizedBox(height: 14),
                      _Benefit(
                        icon: Icons.verified_outlined,
                        text: t('النصوص الدينية ثابتة داخل التطبيق وليست مولدة بالذكاء الاصطناعي', 'Religious text is fixed in-app content, never AI-generated'),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _finish(context),
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: Text(t('إعداد نفحات', 'Set up Nafahat')),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: () => _later(context), child: Text(t('لاحقاً', 'Later'))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Benefit({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: scheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
      ],
    );
  }
}
