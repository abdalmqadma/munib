import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/prayer_provider.dart';
import 'splash_screen.dart';

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.language_rounded, size: 80, color: theme.colorScheme.primary),
              const SizedBox(height: 40),
              Text(
                'اختر لغة التطبيق\nChoose App Language',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 60),
              _buildLanguageBtn(context, 'العربية', 'ar'),
              const SizedBox(height: 20),
              _buildLanguageBtn(context, 'English', 'en'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageBtn(BuildContext context, String label, String code) {
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      height: 65,
      child: OutlinedButton(
        onPressed: () async {
          await context.read<PrayerProvider>().setLanguage(code);
          if (context.mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const SplashScreen()),
            );
          }
        },
        style: OutlinedButton.styleFrom(
          backgroundColor: theme.colorScheme.surface,
        ),
        child: Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
