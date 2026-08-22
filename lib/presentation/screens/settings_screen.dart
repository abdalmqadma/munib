import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_strings.dart';
import '../providers/prayer_provider.dart';
import 'imsakia_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrayerProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(25),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  context.tr('settings'),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _settingsCard(context, [
                      _tile(
                        context,
                        title: context.tr('language'),
                        subtitle: provider.language,
                        icon: Icons.language,
                        onTap: () => _showLanguageDialog(context, provider),
                      ),
                      const Divider(height: 1, indent: 20, endIndent: 20),
                      _tile(
                        context,
                        title: context.tr('location'),
                        subtitle: provider.currentCity,
                        icon: Icons.location_city,
                        onTap: () {},
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _settingsCard(context, [
                      _tile(
                        context,
                        title: context.tr('imsakiaSettings'),
                        subtitle: provider.use24HourFormat
                            ? context.tr('timeFormat24')
                            : context.tr('timeFormat12'),
                        icon: Icons.calendar_month_outlined,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ImsakiaSettingsScreen()),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _settingsCard(context, [
                      _tile(
                        context,
                        title: context.tr('appearance'),
                        subtitle: provider.isDarkMode ? context.tr('dark') : context.tr('light'),
                        icon: provider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                        onTap: () => provider.setDarkMode(!provider.isDarkMode),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _settingsCard(context, [
                      _tile(
                        context,
                        title: context.tr('rateApp'),
                        icon: Icons.star_outline_rounded,
                        onTap: () {},
                      ),
                      const Divider(height: 1, indent: 20, endIndent: 20),
                      _tile(
                        context,
                        title: context.tr('share'),
                        icon: Icons.share_outlined,
                        onTap: () {},
                      ),
                    ]),
                    const SizedBox(height: 36),
                    Text(context.tr('version'), style: theme.textTheme.bodySmall),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsCard(BuildContext context, List<Widget> children) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(children: children),
    );
  }

  Widget _tile(
    BuildContext context, {
    required String title,
    String? subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Icon(Icons.chevron_left_rounded, color: theme.colorScheme.onSurfaceVariant),
      title: Text(title, style: theme.textTheme.titleMedium),
      subtitle: subtitle == null ? null : Text(subtitle, style: theme.textTheme.bodySmall),
      trailing: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: theme.colorScheme.primary, size: 22),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, PrayerProvider provider) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('chooseLanguage'), textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(context.tr('arabic')),
              trailing: provider.languageCode == 'ar' ? const Icon(Icons.check_rounded) : null,
              onTap: () async {
                await provider.setLanguage('ar');
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
            ),
            ListTile(
              title: Text(context.tr('english')),
              trailing: provider.languageCode == 'en' ? const Icon(Icons.check_rounded) : null,
              onTap: () async {
                await provider.setLanguage('en');
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
            ),
          ],
        ),
      ),
    );
  }
}
