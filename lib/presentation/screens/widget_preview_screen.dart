import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_strings.dart';
import '../providers/prayer_coach_provider.dart';
import 'auth_screen.dart';
import 'prayer_coach/training_screen.dart';

class WidgetPreviewScreen extends StatelessWidget {
  const WidgetPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final content = SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _CoachHero(theme: theme, scheme: scheme),
                const SizedBox(height: 26),
                Text(
                  context.tr('choosePrayer'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr('choosePrayerSubtitle'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                _PrayerTile(
                  title: context.tr('fajr'),
                  rakahs: 2,
                  icon: Icons.wb_twilight_rounded,
                  onTap: () => _startTraining(context, context.tr('fajr'), 2),
                ),
                const SizedBox(height: 10),
                _PrayerTile(
                  title: context.tr('dhuhr'),
                  rakahs: 4,
                  icon: Icons.wb_sunny_outlined,
                  onTap: () => _startTraining(context, context.tr('dhuhr'), 4),
                ),
                const SizedBox(height: 10),
                _PrayerTile(
                  title: context.tr('asr'),
                  rakahs: 4,
                  icon: Icons.light_mode_outlined,
                  onTap: () => _startTraining(context, context.tr('asr'), 4),
                ),
                const SizedBox(height: 10),
                _PrayerTile(
                  title: context.tr('maghrib'),
                  rakahs: 3,
                  icon: Icons.sunny_snowing,
                  onTap: () => _startTraining(context, context.tr('maghrib'), 3),
                ),
                const SizedBox(height: 10),
                _PrayerTile(
                  title: context.tr('isha'),
                  rakahs: 4,
                  icon: Icons.nightlight_outlined,
                  onTap: () => _startTraining(context, context.tr('isha'), 4),
                ),
                const SizedBox(height: 20),
                _BasicsCard(
                  onTap: () => _startTraining(
                    context,
                    context.tr('learnBasics'),
                    1,
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      body: isDark
          ? DecoratedBox(
              decoration: const BoxDecoration(
                gradient: AppColors.appBackgroundGradient,
              ),
              child: content,
            )
          : content,
    );
  }

  Future<void> _startTraining(
    BuildContext context,
    String prayerName,
    int rakahs,
  ) async {
    if (FirebaseAuth.instance.currentUser == null) {
      final shouldLogin = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.lock_person_rounded),
          title: Text(context.tr('coachLoginTitle')),
          content: Text(
            context.tr('coachLoginBody'),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.tr('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.tr('continueToLogin')),
            ),
          ],
        ),
      );

      if (shouldLogin == true && context.mounted) {
        final loggedIn = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => const AuthScreen(returnOnSuccess: true),
          ),
        );
        if (loggedIn != true) return;
      }
      if (!context.mounted || FirebaseAuth.instance.currentUser == null) return;
    }

    context.read<PrayerCoachProvider>().startSession(rakahs);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrainingScreen(prayerName: prayerName),
      ),
    );
  }
}

class _CoachHero extends StatelessWidget {
  final ThemeData theme;
  final ColorScheme scheme;

  const _CoachHero({required this.theme, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: theme.brightness == Brightness.dark
            ? AppColors.heroGradient
            : null,
        color: theme.brightness == Brightness.light ? scheme.surface : null,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? AppColors.border
              : scheme.outline,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: scheme.primary.withValues(alpha: .22),
              ),
            ),
            child: Icon(
              Icons.accessibility_new_rounded,
              color: scheme.primary,
              size: 31,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('teachMePrayer'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  context.tr('coachDescription'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrayerTile extends StatelessWidget {
  final String title;
  final int rakahs;
  final IconData icon;
  final VoidCallback onTap;

  const _PrayerTile({
    required this.title,
    required this.rakahs,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(
              alpha: theme.brightness == Brightness.dark ? .84 : 1,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: scheme.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: scheme.primary, size: 27),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$rakahs ${context.tr('rakahs')}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  color: scheme.primary,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BasicsCard extends StatelessWidget {
  final VoidCallback onTap;

  const _BasicsCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                scheme.primary.withValues(alpha: .20),
                scheme.surface.withValues(alpha: .90),
              ],
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: scheme.primary.withValues(alpha: .28),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  color: scheme.primary,
                  size: 29,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('learnBasics'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.tr('stepByStep'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.arrow_back_rounded
                    : Icons.arrow_forward_rounded,
                color: scheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
