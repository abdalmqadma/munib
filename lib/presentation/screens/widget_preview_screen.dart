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
      if (!mounted) return;
      setState(() {
        _permission = permission;
        _running = running;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(bool value) async {
    if (value) {
      if (!_permission) {
        await _channel.invokeMethod('requestOverlayPermission');
        return;
      }
      await _channel.invokeMethod('startNafahat');
    } else {
      await _channel.invokeMethod('stopNafahat');
    }
    await _refreshState();
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
              'آية أو حديث أو أثر طيب يرافقك كفقاعة صغيرة فوق التطبيقات، مثل فقاعات ماسنجر القديمة.',
              'A verse, hadith, or gentle reminder that stays with you as a small floating bubble above other apps.',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 24),
          _PreviewCard(isArabic: _isArabic),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: scheme.outline),
            ),
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
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: dark ? .78 : 1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: scheme.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  icon: Icons.touch_app_rounded,
                  title: t('اضغط الفقاعة', 'Tap the bubble'),
                  body: t('تفتح البطاقة وتعرض النفحة كاملة.', 'Opens the card and shows the full reflection.'),
                ),
                const SizedBox(height: 16),
                _InfoRow(
                  icon: Icons.open_with_rounded,
                  title: t('اسحبها لأي مكان', 'Drag it anywhere'),
                  body: t('مكانها حر على الشاشة ولا تغطي التطبيق.', 'Move it freely so it stays out of your way.'),
                ),
                const SizedBox(height: 16),
                _InfoRow(
                  icon: Icons.auto_awesome_rounded,
                  title: t('تتجدد تلقائياً', 'Refreshes automatically'),
                  body: t('تتغير النفحة كل 30 دقيقة، ويمكنك الضغط على التالي متى شئت.', 'A new reflection appears every 30 minutes, with a Next button anytime.'),
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
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF0B1F3A), Color(0xFF1E88E5)]),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFF4C76A).withValues(alpha: .65)),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFF4C76A)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  isArabic ? 'هكذا تظهر على الشاشة' : 'This is how it appears',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '﴿ألا بذكر الله تطمئن القلوب﴾',
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, height: 1.6, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text('الرعد 28', textAlign: TextAlign.right, style: TextStyle(color: Color(0xFFF4C76A), fontSize: 12)),
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
          decoration: BoxDecoration(color: scheme.primary.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: scheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(body, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.45)),
            ],
          ),
        ),
      ],
    );
  }
}
