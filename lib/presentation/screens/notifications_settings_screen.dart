import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_strings.dart';
import '../providers/prayer_provider.dart';

class NotificationsSettingsScreen extends StatelessWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrayerProvider>();
    final theme = Theme.of(context);
    final isEn = provider.isEnglish;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('notifications')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _section(
            context,
            children: [
              _switchTile(
                context,
                title: isEn ? 'Prayer notifications' : 'إشعارات الصلاة',
                subtitle: isEn ? 'Alert at every prayer time' : 'تنبيه عند كل وقت صلاة',
                icon: Icons.notifications_active_outlined,
                value: provider.prayerNotif,
                onChanged: (v) => provider.updateSetting('prayerNotif', v),
              ),
              const Divider(height: 1),
              _switchTile(
                context,
                title: isEn ? 'Reminder before prayer' : 'تذكير قبل الصلاة',
                subtitle: isEn ? '15 minutes before adhan' : '15 دقيقة قبل الأذان',
                icon: Icons.alarm_outlined,
                value: provider.reminderNotif,
                onChanged: (v) => provider.updateSetting('reminderNotif', v),
              ),
              const Divider(height: 1),
              _switchTile(
                context,
                title: isEn ? 'Morning adhkar' : 'أذكار الصباح',
                subtitle: isEn ? 'After Fajr prayer' : 'بعد صلاة الفجر',
                icon: Icons.wb_sunny_outlined,
                value: provider.azkarNotif,
                onChanged: (v) => provider.updateSetting('azkarNotif', v),
              ),
              const Divider(height: 1),
              _switchTile(
                context,
                title: isEn ? 'Silent mode' : 'الوضع الصامت',
                subtitle: isEn ? 'Notifications without sound' : 'إشعارات بدون صوت',
                icon: Icons.volume_off_rounded,
                value: provider.silentMode,
                onChanged: (v) => provider.updateSetting('silentMode', v),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, bottom: 10),
            child: Text(
              isEn ? 'Adhan sound' : 'صوت الأذان',
              style: theme.textTheme.titleSmall,
            ),
          ),
          _section(
            context,
            children: [
              _radioTile(
                context,
                title: isEn ? 'Default Meccan adhan' : 'المكي الافتراضي',
                subtitle: isEn ? 'Makkah adhan' : 'أذان مكة المكرمة',
                icon: Icons.music_note_rounded,
                selected: provider.adhanVoice == 'Meccan',
                onTap: () => provider.updateSetting('adhanVoice', 'Meccan'),
              ),
              const Divider(height: 1),
              _radioTile(
                context,
                title: isEn ? 'No adhan' : 'بدون أذان',
                subtitle: isEn ? 'Silent notification only' : 'تنبيه صامت فقط',
                icon: Icons.notifications_off_outlined,
                selected: provider.adhanVoice == 'None',
                onTap: () => provider.updateSetting('adhanVoice', 'None'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, {required List<Widget> children}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(children: children),
    );
  }

  Widget _switchTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      activeColor: scheme.primary,
      secondary: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: scheme.primary),
      ),
      title: Text(title, style: theme.textTheme.titleMedium),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    );
  }

  Widget _radioTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? scheme.primary : scheme.onSurfaceVariant,
      ),
      title: Text(title, style: theme.textTheme.titleMedium),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      trailing: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: scheme.primary),
      ),
    );
  }
}
