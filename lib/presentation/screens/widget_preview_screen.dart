import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';

class WidgetPreviewScreen extends StatefulWidget {
  const WidgetPreviewScreen({super.key});

  @override
  State<WidgetPreviewScreen> createState() => _WidgetPreviewScreenState();
}

class _WidgetPreviewScreenState extends State<WidgetPreviewScreen>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('com.example.munib/nafahat');

  bool _loading = true;
  bool _permission = false;
  bool _running = false;
  bool _quietMode = false;
  bool _contextualMode = true;
  int _intervalMinutes = 30;
  int _visibleSeconds = 45;
  Set<String> _enabledKinds = {'آية', 'حديث', 'ذكر', 'أثر طيب'};

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';
  String t(String ar, String en) => _isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshState();
  }

  Future<void> _refreshState() async {
    try {
      final permission = await _channel.invokeMethod<bool>('canDrawOverlays') ?? false;
      final running = await _channel.invokeMethod<bool>('isNafahatRunning') ?? false;
      final raw = await _channel.invokeMapMethod<String, dynamic>('getNafahatSettings');
      if (!mounted) return;
      setState(() {
        _permission = permission;
        _running = running;
        _intervalMinutes = (raw?['intervalMinutes'] as int?) ?? 30;
        _visibleSeconds = (raw?['visibleSeconds'] as int?) ?? 45;
        _quietMode = (raw?['quietMode'] as bool?) ?? false;
        _contextualMode = (raw?['contextualMode'] as bool?) ?? true;
        final kinds = (raw?['enabledKinds'] as List?)?.whereType<String>().toSet();
        if (kinds != null && kinds.isNotEmpty) _enabledKinds = kinds;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveSettings() async {
    await _channel.invokeMethod('setNafahatSettings', {
      'enabledKinds': _enabledKinds.toList(),
      'intervalMinutes': _intervalMinutes,
      'visibleSeconds': _visibleSeconds,
      'quietMode': _quietMode,
      'contextualMode': _contextualMode,
    });
  }

  Future<void> _toggle(bool value) async {
    if (value) {
      if (!_permission) {
        await _channel.invokeMethod('requestOverlayPermission');
        return;
      }
      await _saveSettings();
      await _channel.invokeMethod('startNafahat');
    } else {
      await _channel.invokeMethod('stopNafahat');
    }
    await _refreshState();
  }

  Future<void> _toggleKind(String kind, bool selected) async {
    final next = {..._enabledKinds};
    if (selected) {
      next.add(kind);
    } else if (next.length > 1) {
      next.remove(kind);
    }
    setState(() => _enabledKinds = next);
    await _saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    final body = SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        children: [
          Text(t('نفحات', 'Nafahat'), style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            t(
              'تظهر نفحة قصيرة فوق التطبيقات في الوقت الذي تختاره، ثم تختفي وحدها. عند وصول نفحة جديدة تظهر الحلقة الذهبية حول الفقاعة حتى تفتحها.',
              'A short reflection appears above other apps on your schedule, then disappears automatically. New unread reflections use a subtle gold ring.',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 24),
          _PreviewCard(isArabic: _isArabic),
          const SizedBox(height: 24),
          _SectionCard(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _running,
                  onChanged: _loading ? null : _toggle,
                  secondary: Icon(Icons.auto_awesome_rounded, color: scheme.primary),
                  title: Text(t('تفعيل نفحات', 'Enable Nafahat')),
                  subtitle: Text(
                    _permission
                        ? t('ستظهر فقط عند وقت النفحة', 'It appears only when a reflection is due')
                        : t('يحتاج إذن الظهور فوق التطبيقات', 'Requires display-over-other-apps permission'),
                  ),
                ),
                if (!_permission) ...[
                  const Divider(height: 26),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _channel.invokeMethod('requestOverlayPermission'),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: Text(t('منح الصلاحية', 'Grant permission')),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('الجدول', 'Schedule'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                _DropRow(
                  label: t('تظهر كل', 'Appear every'),
                  value: _intervalMinutes,
                  values: const [10, 20, 30, 60, 120],
                  suffix: _isArabic ? 'دقيقة' : 'min',
                  onChanged: (value) async {
                    setState(() => _intervalMinutes = value);
                    await _saveSettings();
                  },
                ),
                const SizedBox(height: 8),
                _DropRow(
                  label: t('تبقى ظاهرة', 'Stay visible'),
                  value: _visibleSeconds,
                  values: const [20, 30, 45, 60, 120],
                  suffix: _isArabic ? 'ثانية' : 'sec',
                  onChanged: (value) async {
                    setState(() => _visibleSeconds = value);
                    await _saveSettings();
                  },
                ),
                const Divider(height: 28),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _contextualMode,
                  onChanged: (value) async {
                    setState(() => _contextualMode = value);
                    await _saveSettings();
                  },
                  title: Text(t('اختيار ذكي حسب الوقت', 'Smart contextual selection')),
                  subtitle: Text(
                    t(
                      'يراعي الصباح والمساء، يوم الجمعة، ويعطي تذكيراً مناسباً إذا بقي أقل من 20 دقيقة للصلاة القادمة.',
                      'Prioritizes morning/evening content, Friday, and a prayer reminder when the next prayer is under 20 minutes away.',
                    ),
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _quietMode,
                  onChanged: (value) async {
                    setState(() => _quietMode = value);
                    await _saveSettings();
                  },
                  title: Text(t('الوضع الهادئ', 'Quiet mode')),
                  subtitle: Text(
                    t(
                      'بدون صوت أو اهتزاز، وتظهر الفقاعة أخف وتختفي خلال 30 ثانية كحد أقصى.',
                      'No sound or vibration; the bubble is subtler and disappears within 30 seconds.',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('نوع المحتوى', 'Content types'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _kindChip('آية', 'Verses'),
                    _kindChip('حديث', 'Hadith'),
                    _kindChip('ذكر', 'Adhkar'),
                    _kindChip('أثر طيب', 'Reflections'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.swipe_rounded,
                  title: t('Sticky على الحواف', 'Edge snapping'),
                  body: t(
                    'اسحبها لأي مكان، وعند الإفلات تنزلق بسلاسة إلى أقرب حافة يمين أو شمال، مع مساحة آمنة عن شريط الإشعارات وأزرار التنقل.',
                    'Drag it anywhere; on release it smoothly snaps to the nearest left or right edge while staying clear of system bars.',
                  ),
                ),
                const SizedBox(height: 16),
                _InfoRow(
                  icon: Icons.delete_outline_rounded,
                  title: t('اسحب إلى × للإخفاء المؤقت', 'Drag to × to dismiss temporarily'),
                  body: t(
                    'أثناء السحب تظهر دائرة × أسفل الشاشة فوق شريط التنقل. أفلت النفحة عليها فتختفي هذه النفحة فقط ولا تعود قبل الموعد القادم الذي حددته.',
                    'While dragging, an × target appears above navigation. Drop the bubble there to hide only the current reflection until your next scheduled time.',
                  ),
                ),
                const SizedBox(height: 16),
                _InfoRow(
                  icon: Icons.verified_outlined,
                  title: t('محتوى ديني ثابت', 'Fixed religious content'),
                  body: t(
                    'الذكر يظهر مع فضله، والحديث مع فائدته ومصدره، والآية مع تفسير مختصر. سبب النزول لا يظهر كرواية مخصوصة إلا إذا كان مضافاً لمصدر موثوق؛ ولا يولد الذكاء الاصطناعي النصوص الدينية.',
                    'Adhkar include their virtue, hadith include benefit and source, and verses include short tafsir. A specific sabab al-nuzul is shown only when sourced; religious text is never AI-generated.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      body: dark
          ? DecoratedBox(decoration: const BoxDecoration(gradient: AppColors.appBackgroundGradient), child: body)
          : body,
    );
  }

  Widget _kindChip(String ar, String en) {
    final selected = _enabledKinds.contains(ar);
    return FilterChip(selected: selected, label: Text(t(ar, en)), onSelected: (value) => _toggleKind(ar, value));
  }
}

class _DropRow extends StatelessWidget {
  final String label;
  final int value;
  final List<int> values;
  final String suffix;
  final ValueChanged<int> onChanged;
  const _DropRow({required this.label, required this.value, required this.values, required this.suffix, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        DropdownButton<int>(
          value: value,
          items: values.map((v) => DropdownMenuItem(value: v, child: Text('$v $suffix'))).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: scheme.outline)),
      child: child,
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final bool isArabic;
  const _PreviewCard({required this.isArabic});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.gold.withValues(alpha: .28)),
        boxShadow: const [BoxShadow(blurRadius: 22, offset: Offset(0, 10), color: Color(0x26000000))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0B1F3A), Color(0xFF1E88E5)]),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF4C76A), width: 3),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFF4C76A)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(isArabic ? 'نفحة جديدة' : 'New reflection', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 20),
          const Text('﴿ألا بذكر الله تطمئن القلوب﴾', textAlign: TextAlign.right, textDirection: TextDirection.rtl, style: TextStyle(color: Colors.white, fontSize: 21, height: 1.6, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('الرعد: 28', textAlign: TextAlign.right, style: TextStyle(color: Color(0xFFF4C76A), fontSize: 12)),
          const SizedBox(height: 14),
          Text(isArabic ? 'تفسير مختصر: تطمئن قلوب المؤمنين بذكر الله ومعرفته والأنس به.' : 'Short tafsir: believers find reassurance in remembering and knowing Allah.', style: const TextStyle(color: Colors.white70, height: 1.45)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _InfoRow({required this.icon, required this.title, required this.body});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: scheme.primary.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: scheme.primary)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(body, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.45)),
        ])),
      ],
    );
  }
}
