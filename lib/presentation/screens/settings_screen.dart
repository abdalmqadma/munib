import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_strings.dart';
import '../../data/models/prayer_day.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/location_service.dart';
import '../providers/prayer_provider.dart';
import '../providers/theme_provider.dart';
import 'imsakia_settings_screen.dart';
import 'location_imsakia_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prayerProvider = context.watch<PrayerProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final theme = Theme.of(context);
    final ar = Localizations.localeOf(context).languageCode == 'ar';

    String t(String arabic, String english) => ar ? arabic : english;
    String themeLabel() => switch (themeProvider.preference) {
          MunibThemePreference.system => t('حسب الجهاز', 'System default'),
          MunibThemePreference.light => t('فاتح', 'Light'),
          MunibThemePreference.dark => t('داكن', 'Dark'),
        };

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
                    _SettingsCard(
                      children: [
                        _SettingsTile(
                          title: context.tr('language'),
                          subtitle: prayerProvider.language,
                          icon: Icons.language,
                          onTap: () => _showLanguageDialog(
                            context,
                            prayerProvider,
                          ),
                        ),
                        const Divider(height: 1, indent: 20, endIndent: 20),
                        _SettingsTile(
                          title: context.tr('location'),
                          subtitle: prayerProvider.currentCity,
                          icon: Icons.location_city,
                          onTap: () => _showLocationOptions(
                            context,
                            prayerProvider,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SettingsCard(
                      children: [
                        _SettingsTile(
                          title: context.tr('imsakiaSettings'),
                          subtitle: prayerProvider.use24HourFormat
                              ? context.tr('timeFormat24')
                              : context.tr('timeFormat12'),
                          icon: Icons.calendar_month_outlined,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ImsakiaSettingsScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SettingsCard(
                      children: [
                        _SettingsTile(
                          title: context.tr('appearance'),
                          subtitle: themeLabel(),
                          icon: theme.brightness == Brightness.dark
                              ? Icons.dark_mode
                              : Icons.light_mode,
                          onTap: () => _showThemeDialog(
                            context,
                            themeProvider,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),
                    Text(
                      context.tr('version'),
                      style: theme.textTheme.bodySmall,
                    ),
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

  Future<void> _showThemeDialog(
    BuildContext context,
    ThemeProvider provider,
  ) async {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    String t(String arabic, String english) => ar ? arabic : english;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ThemeOption(
              icon: Icons.settings_suggest_outlined,
              title: t('حسب الجهاز', 'System default'),
              subtitle: t(
                'يتبع الوضع الفاتح أو الداكن في هاتفك',
                'Follows your phone light or dark mode',
              ),
              selected: provider.preference == MunibThemePreference.system,
              onTap: () async {
                await provider.setPreference(MunibThemePreference.system);
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
            ),
            _ThemeOption(
              icon: Icons.light_mode_outlined,
              title: t('فاتح', 'Light'),
              selected: provider.preference == MunibThemePreference.light,
              onTap: () async {
                await provider.setPreference(MunibThemePreference.light);
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
            ),
            _ThemeOption(
              icon: Icons.dark_mode_outlined,
              title: t('داكن', 'Dark'),
              selected: provider.preference == MunibThemePreference.dark,
              onTap: () async {
                await provider.setPreference(MunibThemePreference.dark);
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _showLocationOptions(
    BuildContext context,
    PrayerProvider provider,
  ) async {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    String t(String arabic, String english) => ar ? arabic : english;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.my_location_rounded),
                title: Text(t('استخدام موقعي الحالي', 'Use my current location')),
                subtitle: Text(
                  t(
                    'تحديد المدينة من GPS وتحميل مواقيتها',
                    'Detect your city and load its prayer times',
                  ),
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _useCurrentLocation(context, provider);
                },
              ),
              ListTile(
                leading: const Icon(Icons.travel_explore_rounded),
                title: Text(t('اختيار مدينة أخرى', 'Choose another city')),
                subtitle: Text(
                  t('ابحث عن أي مدينة في العالم', 'Search any city worldwide'),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LocationImsakiaScreen(),
                    ),
                  );
                },
              ),
              if (provider.savedLocations.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.bookmarks_outlined),
                  title: Text(
                    t('إدارة المواقع المحفوظة', 'Manage saved locations'),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ImsakiaSettingsScreen(),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _useCurrentLocation(
    BuildContext context,
    PrayerProvider provider,
  ) async {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    String t(String arabic, String english) => ar ? arabic : english;
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      SnackBar(content: Text(t('جاري تحديد موقعك...', 'Detecting your location...'))),
    );

    try {
      final location =
          await LocationService().getCurrentLocation(requestPermission: true);
      final result = await AIService().fetchPrayerTimesForLocation(
        location.latitude,
        location.longitude,
        countryCode: location.countryCode,
      );
      if (result.days.isEmpty) throw Exception('empty');

      final parts = location.city.split(',');
      await provider.addLocationImsakia(
        name: parts.first.trim(),
        country: parts.length > 1
            ? parts.sublist(1).join(',').trim()
            : '',
        latitude: location.latitude,
        longitude: location.longitude,
        timezone: result.timezone,
        prayers: result.days.map(PrayerDay.fromJson).toList(),
      );

      if (context.mounted) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              t(
                'تم تحديث موقعك: ${provider.currentCity}',
                'Location updated: ${provider.currentCity}',
              ),
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              t(
                'تعذر تحديد الموقع. تأكد من GPS والصلاحية وحاول مجدداً.',
                'Could not detect location. Check GPS and permission, then try again.',
              ),
            ),
          ),
        );
      }
    }
  }

  void _showLanguageDialog(
    BuildContext context,
    PrayerProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          context.tr('chooseLanguage'),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(context.tr('arabic')),
              trailing: provider.languageCode == 'ar'
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () async {
                await provider.setLanguage('ar');
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
            ),
            ListTile(
              title: Text(context.tr('english')),
              trailing: provider.languageCode == 'en'
                  ? const Icon(Icons.check_rounded)
                  : null,
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

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: scheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Icon(
        Icons.chevron_left_rounded,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(title, style: theme.textTheme.titleMedium),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: theme.textTheme.bodySmall),
      trailing: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: theme.colorScheme.primary, size: 22),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: selected ? const Icon(Icons.check_rounded) : null,
      onTap: onTap,
    );
  }
}
