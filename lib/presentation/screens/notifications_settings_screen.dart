import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_strings.dart';
import '../../data/services/notification_service.dart';
import '../providers/prayer_provider.dart';

class NotificationsSettingsScreen extends StatelessWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrayerProvider>();
    final theme = Theme.of(context);
    final isEn = provider.isEnglish;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('notifications'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _section(
            context,
            children: [
              _switchTile(
                context,
                title: isEn ? 'Prayer notifications' : 'إشعارات الصلاة',
                subtitle: isEn
                    ? 'Notify you at the exact prayer time'
                    : 'تنبيه عند دخول وقت كل صلاة',
                icon: Icons.notifications_active_outlined,
                value: provider.prayerNotif,
                onChanged: (value) =>
                    _setPrayerNotifications(context, provider, value),
              ),
              const Divider(height: 1),
              _switchTile(
                context,
                title: isEn ? 'Reminder before prayer' : 'تذكير قبل الصلاة',
                subtitle: isEn
                    ? '15 minutes by default, customizable per prayer'
                    : '15 دقيقة افتراضيًا، ويمكن تخصيص كل صلاة',
                icon: Icons.alarm_outlined,
                value: provider.reminderNotif,
                onChanged: provider.prayerNotif
                    ? provider.setReminderNotificationsEnabled
                    : null,
              ),
              const Divider(height: 1),
              _switchTile(
                context,
                title: isEn ? 'Morning adhkar' : 'أذكار الصباح',
                subtitle: isEn
                    ? '15 minutes after Fajr'
                    : 'بعد الفجر بـ 15 دقيقة',
                icon: Icons.wb_sunny_outlined,
                value: provider.morningAzkarNotif,
                onChanged: (value) =>
                    _setMorningAzkar(context, provider, value),
              ),
              const Divider(height: 1),
              _switchTile(
                context,
                title: isEn ? 'Evening adhkar' : 'أذكار المساء',
                subtitle: isEn
                    ? '15 minutes after Maghrib'
                    : 'بعد المغرب بـ 15 دقيقة',
                icon: Icons.nights_stay_outlined,
                value: provider.eveningAzkarNotif,
                onChanged: (value) =>
                    _setEveningAzkar(context, provider, value),
              ),
              const Divider(height: 1),
              _switchTile(
                context,
                title: isEn ? 'Silent mode' : 'الوضع الصامت',
                subtitle: isEn
                    ? 'Keep alerts without adhan audio'
                    : 'تبقى التنبيهات بدون تشغيل صوت الأذان',
                icon: Icons.volume_off_rounded,
                value: provider.silentMode,
                onChanged: provider.setSilentMode,
              ),
            ],
          ),
          if (provider.prayerNotif) ...[
            const SizedBox(height: 26),
            _sectionTitle(
              context,
              isEn ? 'Customize each prayer' : 'تخصيص كل صلاة',
            ),
            _section(
              context,
              children: [
                for (var i = 0;
                    i < PrayerProvider.notificationPrayers.length;
                    i++) ...[
                  _prayerTile(
                    context,
                    provider,
                    PrayerProvider.notificationPrayers[i],
                  ),
                  if (i != PrayerProvider.notificationPrayers.length - 1)
                    const Divider(height: 1),
                ],
              ],
            ),
          ],
          const SizedBox(height: 26),
          _sectionTitle(context, isEn ? 'Adhan sound' : 'صوت الأذان'),
          _section(
            context,
            children: [
              _radioTile(
                context,
                title: isEn ? 'Madinah adhan' : 'أذان الحرم المدني',
                subtitle: isEn
                    ? 'Default Munib adhan'
                    : 'الصوت الافتراضي في منيب',
                icon: Icons.mosque_outlined,
                selected: provider.adhanVoice == 'Madinah',
                onTap: () => provider.setAdhanVoice('Madinah'),
              ),
              const Divider(height: 1),
              _radioTile(
                context,
                title: isEn ? 'Makkah adhan' : 'أذان الحرم المكي',
                subtitle: isEn ? 'Makkah style' : 'خيار إضافي للأذان',
                icon: Icons.mosque_rounded,
                selected: provider.adhanVoice == 'Meccan',
                onTap: () => provider.setAdhanVoice('Meccan'),
              ),
              const Divider(height: 1),
              _radioTile(
                context,
                title: isEn ? 'No adhan' : 'بدون أذان',
                subtitle: isEn
                    ? 'Prayer notification only'
                    : 'إشعار الصلاة فقط بدون صوت',
                icon: Icons.notifications_off_outlined,
                selected: provider.adhanVoice == 'None',
                onTap: () => provider.setAdhanVoice('None'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            isEn
                ? 'Exact alarm access is requested only when you enable time-sensitive alerts. If Android does not grant it, Munib falls back to a less precise system schedule instead of failing silently.'
                : 'يطلب منيب صلاحية المنبّه الدقيق فقط عند تفعيل التنبيهات المرتبطة بالوقت. إذا لم يمنحها أندرويد، يستخدم جدولة أقل دقة بدل أن تتعطل التنبيهات بصمت.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _setPrayerNotifications(
    BuildContext context,
    PrayerProvider provider,
    bool value,
  ) async {
    final ok = await provider.setPrayerNotificationsEnabled(value);
    if (!context.mounted || !value) return;
    if (!ok) {
      _showMessage(
        context,
        provider.isEnglish
            ? 'Notification permission is required.'
            : 'يلزم السماح بالإشعارات لتفعيل هذا الخيار.',
      );
      return;
    }
    final state = await NotificationService.permissionState();
    if (!context.mounted || state.exactAlarmsAllowed) return;
    _showMessage(
      context,
      provider.isEnglish
          ? 'Exact alarm access was not granted. Android may deliver prayer alerts a little late.'
          : 'لم تُمنح صلاحية المنبّه الدقيق. قد يؤخر أندرويد التنبيه قليلًا.',
    );
  }

  Future<void> _setMorningAzkar(
    BuildContext context,
    PrayerProvider provider,
    bool value,
  ) async {
    final ok = await provider.setMorningAzkarNotificationsEnabled(value);
    if (!context.mounted || ok || !value) return;
    _showPermissionDenied(context, provider.isEnglish);
  }

  Future<void> _setEveningAzkar(
    BuildContext context,
    PrayerProvider provider,
    bool value,
  ) async {
    final ok = await provider.setEveningAzkarNotificationsEnabled(value);
    if (!context.mounted || ok || !value) return;
    _showPermissionDenied(context, provider.isEnglish);
  }

  Widget _prayerTile(
    BuildContext context,
    PrayerProvider provider,
    String prayer,
  ) {
    final enabled = provider.isPrayerNotificationEnabled(prayer);
    final minutes = provider.reminderMinutesFor(prayer);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = _localizedPrayer(prayer, provider.isEnglish);

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 10, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(
                  provider.reminderNotif
                      ? (provider.isEnglish
                          ? '$minutes minutes before prayer'
                          : 'التذكير قبلها بـ $minutes دقيقة')
                      : (provider.isEnglish
                          ? 'Pre-prayer reminder is off'
                          : 'تذكير ما قبل الصلاة متوقف'),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (provider.reminderNotif && enabled)
            TextButton(
              onPressed: () => _editReminderMinutes(context, provider, prayer),
              child: Text(provider.isEnglish ? '$minutes min' : '$minutes د'),
            ),
          Switch.adaptive(
            value: enabled,
            activeColor: scheme.primary,
            onChanged: (value) =>
                provider.setPrayerNotificationEnabled(prayer, value),
          ),
        ],
      ),
    );
  }

  Future<void> _editReminderMinutes(
    BuildContext context,
    PrayerProvider provider,
    String prayer,
  ) async {
    final controller = TextEditingController(
      text: provider.reminderMinutesFor(prayer).toString(),
    );
    final isEn = provider.isEnglish;
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          isEn
              ? 'Reminder for ${_localizedPrayer(prayer, true)}'
              : 'تذكير صلاة ${_localizedPrayer(prayer, false)}',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: isEn ? 'Minutes before prayer' : 'دقائق قبل الصلاة',
            helperText: isEn
                ? 'Enter any valid value that does not cross the previous prayer.'
                : 'أدخل أي مدة لا تتداخل مع وقت الصلاة السابقة.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(isEn ? 'Cancel' : 'إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value != null) Navigator.pop(dialogContext, value);
            },
            child: Text(isEn ? 'Save' : 'حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !context.mounted) return;

    final saved = await provider.setPrayerReminderMinutes(prayer, result);
    if (!context.mounted || saved) return;
    _showMessage(
      context,
      isEn
          ? 'This reminder overlaps the previous prayer time. Choose a shorter duration.'
          : 'هذه المدة تتداخل مع وقت الصلاة السابقة. اختر مدة أقصر.',
    );
  }

  Widget _sectionTitle(BuildContext context, String title) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 4, bottom: 10),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall),
      );

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
    required ValueChanged<bool>? onChanged,
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

  void _showPermissionDenied(BuildContext context, bool isEn) {
    _showMessage(
      context,
      isEn
          ? 'Notification permission is required.'
          : 'يلزم السماح بالإشعارات لتفعيل هذا الخيار.',
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _localizedPrayer(String prayer, bool isEn) {
    if (isEn) return prayer;
    return switch (prayer) {
      'Fajr' => 'الفجر',
      'Dhuhr' => 'الظهر',
      'Asr' => 'العصر',
      'Maghrib' => 'المغرب',
      'Isha' => 'العشاء',
      _ => prayer,
    };
  }
}
