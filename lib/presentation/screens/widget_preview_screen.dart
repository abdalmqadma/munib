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
  int _intervalMinutes = 30;
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
        _quietMode = (raw?['quietMode'] as bool?) ?? false;
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
      'quietMode': _quietMode,
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
          Text(
            t('نفحات', 'Reflections'),
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            t(
              'فقاعة خفيفة تلتصق بأقرب حافة وتعرض آية بتفسيرها، حديثاً، ذكراً بفضله أو أثراً طيباً من محتوى ثابت داخل منيب.',
              'A lightweight edge-snapping bubble with verses and short tafsir, hadith, adhkar with virtues, and gentle reminders from fixed local content.',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
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
                  secondary: Icon(Icons.bubble_chart_rounded, color: scheme.primary),
                  title: Text(t('إظهار فقاعة نفحات', 'Show Nafahat bubble')),
                  subtitle: Text(
                    _permission
                        ? t('الصلاحية جاهزة', 'Permission ready')
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
                Text(t('المحتوى', 'Content'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
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
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: Text(t('التجديد التلقائي', 'Auto refresh'))),
                    DropdownButton<int>(
                      value: _intervalMinutes,
                      items: const [10, 20, 30, 60, 120]
                          .map((m) => DropdownMenuItem(value: m, child: Text('$m min')))
                          .toList(),
                      onChanged: (value) async {
                        if (value == null) return;
                        setState(() => _intervalMinutes = value);
                        await _saveSettings();
                      },
                    ),
                  ],
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
                      'تظهر الحلقة الذهبية عند وصول نفحة جديدة ثم تخفت الفقاعة بعد ثوانٍ إذا لم تفتحها.',
                      'A gold ring marks new content, then the bubble gently dims if left unopened.',
                    ),
                  ),
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
                    'إذا سحبت الفقاعة للنص ترجع بسلاسة إلى أقرب حافة يمين أو شمال مع إبقائها بعيداً عن شريط الإشعارات وأزرار التنقل.',
                    'Dragging toward the middle smoothly snaps the bubble to the nearest left or right edge while avoiding system bars.',
                  ),
                ),
                const SizedBox(height: 16),
                _InfoRow(
                  icon: Icons.delete_outline_rounded,
                  title: t('اسحب للحذف', 'Drag to remove'),
                  body: t(
                    'أثناء السحب يظهر هدف حذف فوق منطقة التنقل؛ أفلت الفقاعة عليه لإيقاف نفحات فوراً.',
                    'A remove target appears above the navigation area while dragging; drop the bubble there to stop Nafahat.',
                  ),
                ),
                const SizedBox(height: 16),
                _InfoRow(
                  icon: Icons.verified_outlined,
                  title: t('المحتوى ثابت وموثوق', 'Fixed source content'),
                  body: t(
                    'النصوص الدينية لا يتم توليدها بالذكاء الاصطناعي. الآيات والأحاديث والأذكار محفوظة محلياً، ومع الآية يظهر تفسير مختصر وسبب النزول عندما نملك صياغة موثوقة.',
                    'Religious text is never AI-generated. Verses, hadith and adhkar are local fixed content, with short tafsir and sabab al-nuzul only where confidently sourced.',
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
          ? DecoratedBox(
              decoration: const BoxDecoration(gradient: AppColors.appBackgroundGradient),
              child: body,
            )
          : body,
    );
  }

  Widget _kindChip(String ar, String en) {
    final selected = _enabledKinds.contains(ar);
    return FilterChip(
      selected: selected,
      label: Text(t(ar, en)),
      onSelected: (value) => _toggleKind(ar, value),
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
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outline),
      ),
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
        boxShadow: const [
          BoxShadow(blurRadius: 22, offset: Offset(0, 10), color: Color(0x26000000)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
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
              Expanded(
                child: Text(
                  isArabic ? 'نفحة جديدة' : 'New reflection',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '﴿ألا بذكر الله تطمئن القلوب﴾',
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  height: 1.6,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          const Text(
            'الرعد: 28',
            textAlign: TextAlign.right,
            style: TextStyle(color: Color(0xFFF4C76A), fontSize: 12),
          ),
          const SizedBox(height: 14),
          Text(
            isArabic
                ? 'تفسير مختصر: تطمئن قلوب المؤمنين بذكر الله ومعرفته والأنس به.'
                : 'Short tafsir: believers find reassurance in remembering and knowing Allah.',
            textAlign: TextAlign.start,
            style: const TextStyle(color: Colors.white70, height: 1.45),
          ),
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
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: scheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(
                body,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.45,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
