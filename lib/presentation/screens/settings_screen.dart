import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_strings.dart';
import '../../data/models/prayer_day.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/location_service.dart';
import '../providers/prayer_provider.dart';
import 'imsakia_settings_screen.dart';
import 'location_imsakia_screen.dart';

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
                        onTap: () => _showLocationOptions(context, provider),
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
    final radius = BorderRadius.circular(24);
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
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

  Future<void> _showLocationOptions(BuildContext context, PrayerProvider provider) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    String t(String ar, String en) => isArabic ? ar : en;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                  child: Text(
                    t('تغيير المدينة', 'Change city'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.my_location_rounded),
                title: Text(t('استخدام موقعي الحالي', 'Use my current location')),
                subtitle: Text(t('تحديد المدينة من GPS وتحميل مواقيتها', 'Detect your city and load its prayer times')),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _useCurrentLocation(context, provider);
                },
              ),
              ListTile(
                leading: const Icon(Icons.travel_explore_rounded),
                title: Text(t('اختيار مدينة أخرى', 'Choose another city')),
                subtitle: Text(t('ابحث عن أي مدينة أو دولة في العالم', 'Search any city or country worldwide')),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LocationImsakiaScreen()),
                  );
                },
              ),
              if (provider.savedLocations.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.bookmarks_outlined),
                  title: Text(t('إدارة المواقع المحفوظة', 'Manage saved locations')),
                  subtitle: Text(t('تبديل أو حذف الإمساكيات المحفوظة', 'Switch or remove saved prayer locations')),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ImsakiaSettingsScreen()),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _useCurrentLocation(BuildContext context, PrayerProvider provider) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    String t(String ar, String en) => isArabic ? ar : en;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(t('جاري تحديد موقعك وتحميل المواقيت...', 'Detecting your location and loading prayer times...'))),
    );

    try {
      final location = await LocationService().getCurrentLocation(requestPermission: true);
      final result = await AIService().fetchPrayerTimesForLocation(
        location.latitude,
        location.longitude,
      );
      if (result.days.isEmpty) throw Exception('empty_prayer_response');

      final parts = location.city.split(',');
      final city = parts.isNotEmpty ? parts.first.trim() : location.city;
      final country = parts.length > 1 ? parts.sublist(1).join(',').trim() : '';

      await provider.addLocationImsakia(
        name: city,
        country: country,
        latitude: location.latitude,
        longitude: location.longitude,
        timezone: result.timezone,
        prayers: result.days.map(PrayerDay.fromJson).toList(),
      );

      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text(t('تم تحديث مدينتك إلى ${provider.currentCity}', 'City updated to ${provider.currentCity}'))),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      final raw = e.toString();
      final message = raw.contains('denied_forever')
          ? t('صلاحية الموقع مرفوضة نهائيًا. فعّلها من إعدادات الهاتف.', 'Location permission is permanently denied. Enable it in phone settings.')
          : raw.contains('service_disabled')
              ? t('خدمة الموقع مغلقة على الهاتف.', 'Location services are disabled on the phone.')
              : raw.contains('permission_denied')
                  ? t('لم يتم منح صلاحية الموقع.', 'Location permission was not granted.')
                  : t('تعذر تحديث المدينة الآن. حاول مرة أخرى.', 'Could not update the city right now. Try again.');
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
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
