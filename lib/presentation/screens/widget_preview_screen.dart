import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_strings.dart';
import '../providers/prayer_coach_provider.dart';
import 'auth_screen.dart';
import 'prayer_coach/training_screen.dart';

class WidgetPreviewScreen extends StatelessWidget {
  const WidgetPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('choosePrayer'),
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(context.tr('choosePrayerSubtitle'), style: theme.textTheme.bodyMedium),
              const SizedBox(height: 28),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: .95,
                  children: [
                    _prayerOption(context, context.tr('fajr'), 2, Icons.wb_twilight_rounded),
                    _prayerOption(context, context.tr('dhuhr'), 4, Icons.wb_sunny_rounded),
                    _prayerOption(context, context.tr('asr'), 4, Icons.filter_drama_rounded),
                    _prayerOption(context, context.tr('maghrib'), 3, Icons.wb_twilight_sharp),
                    _prayerOption(context, context.tr('isha'), 4, Icons.nightlight_round),
                    _learningOption(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _prayerOption(BuildContext context, String title, int rakahs, IconData icon) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: () => _startTraining(context, title, rakahs),
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: scheme.outline),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: scheme.primary, size: 34),
            ),
            const SizedBox(height: 14),
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('$rakahs ${context.tr('rakahs')}', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _learningOption(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: () => _startTraining(context, context.tr('learnBasics'), 1),
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [scheme.primary.withValues(alpha: .28), scheme.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: scheme.primary.withValues(alpha: .35)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_rounded, color: scheme.primary, size: 38),
            const SizedBox(height: 14),
            Text(context.tr('learnBasics'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(context.tr('stepByStep'), style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Future<void> _startTraining(BuildContext context, String prayerName, int rakahs) async {
    if (FirebaseAuth.instance.currentUser == null) {
      final shouldLogin = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.lock_person_rounded),
          title: Text(context.tr('coachLoginTitle')),
          content: Text(context.tr('coachLoginBody'), textAlign: TextAlign.center),
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
          MaterialPageRoute(builder: (_) => const AuthScreen(returnOnSuccess: true)),
        );
        if (loggedIn != true) return;
      }
      if (!context.mounted || FirebaseAuth.instance.currentUser == null) return;
    }

    context.read<PrayerCoachProvider>().startSession(rakahs);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TrainingScreen(prayerName: prayerName)),
    );
  }
}
