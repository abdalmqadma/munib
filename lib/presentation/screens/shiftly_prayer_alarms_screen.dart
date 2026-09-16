import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/prayer_times/data/prayer_times_service.dart';
import '../providers/prayer_provider.dart';

class ShiftlyPrayerAlarmsScreen extends StatefulWidget {
  const ShiftlyPrayerAlarmsScreen({super.key});

  @override
  State<ShiftlyPrayerAlarmsScreen> createState() =>
      _ShiftlyPrayerAlarmsScreenState();
}

class _ShiftlyPrayerAlarmsScreenState
    extends State<ShiftlyPrayerAlarmsScreen> {
  static const _prefsKey = 'shiftly_prayer_alarm_config_v1';

  final Map<String, _PrayerConfig> _configs = {
    'Fajr': const _PrayerConfig(enabled: true, offsetMinutes: -10, challenge: true),
    'Dhuhr': const _PrayerConfig(enabled: false, offsetMinutes: 0, challenge: false),
    'Asr': const _PrayerConfig(enabled: false, offsetMinutes: 0, challenge: false),
    'Maghrib': const _PrayerConfig(enabled: false, offsetMinutes: 0, challenge: false),
    'Isha': const _PrayerConfig(enabled: true, offsetMinutes: 0, challenge: true),
  };

  bool _loading = true;
  bool _syncing = false;
  bool? _shiftlyInstalled;

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';

  String _t(String ar, String en) => _isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          if (_configs.containsKey(entry.key) && entry.value is Map) {
            _configs[entry.key] = _PrayerConfig.fromJson(
              Map<String, dynamic>.from(entry.value as Map),
            );
          }
        }
      } catch (_) {}
    }

    bool? installed;
    try {
      installed = await canLaunchUrl(Uri.parse('shiftly://prayer-sync'));
    } catch (_) {
      installed = false;
    }

    if (!mounted) return;
    setState(() {
      _shiftlyInstalled = installed;
      _loading = false;
    });
  }

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(
        _configs.map((key, value) => MapEntry(key, value.toJson())),
      ),
    );
  }

  Future<void> _syncWithShiftly() async {
    if (_syncing) return;
    final provider = context.read<PrayerProvider>();
    final activeId = provider.activeLocationId;
    if (activeId == null) {
      _showMessage(
        _t(
          'أضف مواقيت الصلاة أو حدّد موقعك أولًا.',
          'Add prayer times or choose your location first.',
        ),
      );
      return;
    }

    final matches = provider.savedLocations.where((item) => item.id == activeId);
    if (matches.isEmpty) {
      _showMessage(
        _t(
          'تعذر قراءة موقع الإمساكية الحالية.',
          'Could not read the active prayer-times location.',
        ),
      );
      return;
    }

    setState(() => _syncing = true);
    await _saveLocal();

    final location = matches.first;
    final profile = PrayerCalculationProfile.forLocation(
      latitude: location.latitude,
      longitude: location.longitude,
    );

    final rules = _configs.entries
        .map(
          (entry) => {
            'prayer': entry.key,
            'enabled': entry.value.enabled,
            'offsetMinutes': entry.value.offsetMinutes,
            'challengeEnabled': entry.value.challenge,
          },
        )
        .toList();

    final uri = Uri(
      scheme: 'shiftly',
      host: 'prayer-sync',
      queryParameters: {
        'lat': location.latitude.toString(),
        'lon': location.longitude.toString(),
        'method': profile.method.toString(),
        'school': profile.school.toString(),
        if (profile.tune != null) 'tune': profile.tune!,
        'rules': jsonEncode(rules),
      },
    );

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      setState(() {
        _syncing = false;
        _shiftlyInstalled = opened;
      });
      if (!opened) {
        _showMessage(
          _t(
            'لم يتم العثور على Shiftly. ثبّت آخر نسخة ثم حاول مجددًا.',
            'Shiftly was not found. Install the latest build and try again.',
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _syncing = false;
        _shiftlyInstalled = false;
      });
      _showMessage(
        _t(
          'تعذر فتح Shiftly على هذا الجهاز.',
          'Could not open Shiftly on this device.',
        ),
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _update(String prayer, _PrayerConfig config) {
    setState(() => _configs[prayer] = config);
    _saveLocal();
  }

  String _prayerName(String prayer) => switch (prayer) {
        'Fajr' => _t('الفجر', 'Fajr'),
        'Dhuhr' => _t('الظهر', 'Dhuhr'),
        'Asr' => _t('العصر', 'Asr'),
        'Maghrib' => _t('المغرب', 'Maghrib'),
        'Isha' => _t('العشاء', 'Isha'),
        _ => prayer,
      };

  IconData _prayerIcon(String prayer) => switch (prayer) {
        'Fajr' => Icons.bedtime_outlined,
        'Dhuhr' => Icons.wb_sunny_outlined,
        'Asr' => Icons.light_mode_outlined,
        'Maghrib' => Icons.sunny_snowing,
        'Isha' => Icons.nightlight_outlined,
        _ => Icons.mosque_outlined,
      };

  String _offsetText(int minutes) {
    if (minutes == 0) return _t('عند الأذان', 'At prayer time');
    if (minutes < 0) {
      return _t(
        'قبل الأذان بـ ${minutes.abs()} دقيقة',
        '${minutes.abs()} min before',
      );
    }
    return _t('بعد الأذان بـ $minutes دقيقة', '$minutes min after');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<PrayerProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('منبهات الصلاة عبر Shiftly', 'Shiftly prayer alarms')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.link_rounded,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _t(
                                  'منيب × Shiftly',
                                  'Munib × Shiftly',
                                ),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            _StatusBadge(installed: _shiftlyInstalled),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _t(
                            'اختَر الصلوات وطريقة التنبيه مرة واحدة. Shiftly سيحسب الموعد الجديد تلقائيًا كل يوم حسب مواقيت منيب.',
                            'Choose prayers and alarm behavior once. Shiftly will recalculate the alarm automatically every day using Munib prayer settings.',
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${_t('الموقع الحالي', 'Current location')}: ${provider.currentCity}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  for (final prayer in _configs.keys) ...[
                    _PrayerAlarmCard(
                      name: _prayerName(prayer),
                      icon: _prayerIcon(prayer),
                      config: _configs[prayer]!,
                      offsetText: _offsetText(_configs[prayer]!.offsetMinutes),
                      atPrayerLabel: _t('عند الأذان', 'At time'),
                      before10Label: _t('قبل 10 د', '10 min before'),
                      before15Label: _t('قبل 15 د', '15 min before'),
                      challengeTitle: _t('تحدي الاستيقاظ', 'Wake-up challenge'),
                      challengeSubtitle: _t(
                        'لا يوقف المنبه إلا بعد حل البازل',
                        'Require the puzzle before dismissing the alarm',
                      ),
                      onChanged: (value) => _update(prayer, value),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _syncing ? null : _syncWithShiftly,
                    icon: _syncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync_rounded),
                    label: Text(
                      _t(
                        'حفظ ومزامنة مع Shiftly',
                        'Save and sync with Shiftly',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _t(
                      'النغمة يتم اختيارها من Shiftly حتى يحتفظ التطبيق بصلاحية تشغيل ملف النغمة بشكل صحيح.',
                      'Ringtones are chosen inside Shiftly so it keeps the correct permission to play the selected audio.',
                    ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.installed});

  final bool? installed;

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final scheme = Theme.of(context).colorScheme;
    final ok = installed == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (ok ? scheme.primary : scheme.surface).withValues(alpha: .72),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        ok ? (ar ? 'Shiftly مثبت' : 'Shiftly installed') : (ar ? 'غير متصل' : 'Not connected'),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: ok ? scheme.onPrimary : scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _PrayerAlarmCard extends StatelessWidget {
  const _PrayerAlarmCard({
    required this.name,
    required this.icon,
    required this.config,
    required this.offsetText,
    required this.atPrayerLabel,
    required this.before10Label,
    required this.before15Label,
    required this.challengeTitle,
    required this.challengeSubtitle,
    required this.onChanged,
  });

  final String name;
  final IconData icon;
  final _PrayerConfig config;
  final String offsetText;
  final String atPrayerLabel;
  final String before10Label;
  final String before15Label;
  final String challengeTitle;
  final String challengeSubtitle;
  final ValueChanged<_PrayerConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: scheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: config.enabled,
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: scheme.primary),
        ),
        title: Text(name, style: theme.textTheme.titleMedium),
        subtitle: Text(config.enabled ? offsetText : (Localizations.localeOf(context).languageCode == 'ar' ? 'غير مفعّل' : 'Disabled')),
        trailing: Switch.adaptive(
          value: config.enabled,
          onChanged: (value) => onChanged(config.copyWith(enabled: value)),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Divider(),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              offsetText,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Slider(
            value: config.offsetMinutes.toDouble(),
            min: -60,
            max: 60,
            divisions: 24,
            label: offsetText,
            onChanged: config.enabled
                ? (value) => onChanged(
                      config.copyWith(offsetMinutes: value.round()),
                    )
                : null,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text(atPrayerLabel),
                selected: config.offsetMinutes == 0,
                onSelected: config.enabled
                    ? (_) => onChanged(config.copyWith(offsetMinutes: 0))
                    : null,
              ),
              ChoiceChip(
                label: Text(before10Label),
                selected: config.offsetMinutes == -10,
                onSelected: config.enabled
                    ? (_) => onChanged(config.copyWith(offsetMinutes: -10))
                    : null,
              ),
              ChoiceChip(
                label: Text(before15Label),
                selected: config.offsetMinutes == -15,
                onSelected: config.enabled
                    ? (_) => onChanged(config.copyWith(offsetMinutes: -15))
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: config.challenge,
            onChanged: config.enabled
                ? (value) => onChanged(config.copyWith(challenge: value))
                : null,
            title: Text(challengeTitle),
            subtitle: Text(challengeSubtitle),
            secondary: const Icon(Icons.extension_rounded),
          ),
        ],
      ),
    );
  }
}

class _PrayerConfig {
  const _PrayerConfig({
    required this.enabled,
    required this.offsetMinutes,
    required this.challenge,
  });

  final bool enabled;
  final int offsetMinutes;
  final bool challenge;

  _PrayerConfig copyWith({
    bool? enabled,
    int? offsetMinutes,
    bool? challenge,
  }) =>
      _PrayerConfig(
        enabled: enabled ?? this.enabled,
        offsetMinutes: offsetMinutes ?? this.offsetMinutes,
        challenge: challenge ?? this.challenge,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'offsetMinutes': offsetMinutes,
        'challenge': challenge,
      };

  factory _PrayerConfig.fromJson(Map<String, dynamic> json) => _PrayerConfig(
        enabled: json['enabled'] as bool? ?? false,
        offsetMinutes: (json['offsetMinutes'] as num?)?.toInt() ?? 0,
        challenge: json['challenge'] as bool? ?? false,
      );
}
