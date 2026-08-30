import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_colors.dart';
import '../providers/theme_provider.dart';

class WidgetPreviewScreen extends StatefulWidget {
  const WidgetPreviewScreen({super.key});

  @override
  State<WidgetPreviewScreen> createState() => _WidgetPreviewScreenState();
}

class _WidgetPreviewScreenState extends State<WidgetPreviewScreen>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('com.example.munib/nafahat');
  static const _introKey = 'nafahat_intro_v2_seen';

  bool _loading = true;
  bool _introLoading = true;
  bool _showIntro = false;
  bool _permission = false;
  bool _running = false;
  bool _contextualMode = true;
  int _intervalMinutes = 30;
  String? _lastThemeMode;
  Set<String> _enabledKinds = {'آية', 'حديث', 'ذكر', 'أثر طيب'};

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';
  String t(String ar, String en) => _isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadIntroState();
    _refreshState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mode = context.read<ThemeProvider>().preference.name;
    if (_lastThemeMode == mode) return;
    _lastThemeMode = mode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncAppearance(mode);
    });
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

  Future<void> _loadIntroState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _showIntro = !(prefs.getBool(_introKey) ?? false);
      _introLoading = false;
    });
  }

  Future<void> _finishIntro() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_introKey, true);
    if (mounted) setState(() => _showIntro = false);
  }

  Future<void> _refreshState() async {
    try {
      final permission =
          await _channel.invokeMethod<bool>('canDrawOverlays') ?? false;
      final running =
          await _channel.invokeMethod<bool>('isNafahatRunning') ?? false;
      final raw =
          await _channel.invokeMapMethod<String, dynamic>('getNafahatSettings');
      if (!mounted) return;
      setState(() {
        _permission = permission;
        _running = running;
        _intervalMinutes = (raw?['intervalMinutes'] as int?) ?? 30;
        _contextualMode = (raw?['contextualMode'] as bool?) ?? true;
        final kinds =
            (raw?['enabledKinds'] as List?)?.whereType<String>().toSet();
        if (kinds != null && kinds.isNotEmpty) _enabledKinds = kinds;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _syncAppearance(String themeMode) async {
    try {
      await _channel.invokeMethod('setNafahatAppearance', {
        'themeMode': themeMode,
      });
    } catch (_) {}
  }

  Future<void> _saveSettings() async {
    try {
      await _channel.invokeMethod('setNafahatSettings', {
        'enabledKinds': _enabledKinds.toList(),
        'intervalMinutes': _intervalMinutes,
        'contextualMode': _contextualMode,
      });
    } catch (_) {}
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

    if (_introLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_showIntro) {
      return Scaffold(
        body: _NafahatOnboarding(
          isArabic: _isArabic,
          onDone: _finishIntro,
        ),
      );
    }

    final body = SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        children: [
          Text(
            t('نفحات', 'Nafahat'),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          _PreviewCard(isArabic: _isArabic),
          const SizedBox(height: 20),
          _SectionCard(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _running,
                  onChanged: _loading ? null : _toggle,
                  secondary: Icon(
                    Icons.auto_awesome_rounded,
                    color: scheme.primary,
                  ),
                  title: Text(t('تفعيل نفحات', 'Enable Nafahat')),
                  subtitle: Text(
                    _permission
                        ? t(
                            'تبقى النفحة ظاهرة حتى تخفيها بنفسك',
                            'A Nafha stays visible until you hide it',
                          )
                        : t(
                            'يحتاج إذن الظهور فوق التطبيقات',
                            'Requires display-over-other-apps permission',
                          ),
                  ),
                ),
                if (!_permission) ...[
                  const Divider(height: 26),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () =>
                          _channel.invokeMethod('requestOverlayPermission'),
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
                Text(
                  t('الجدول', 'Schedule'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
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
                const Divider(height: 28),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _contextualMode,
                  onChanged: (value) async {
                    setState(() => _contextualMode = value);
                    await _saveSettings();
                  },
                  title: Text(
                    t('اختيار ذكي حسب الوقت', 'Smart contextual selection'),
                  ),
                  subtitle: Text(
                    t(
                      'يراعي الصباح والمساء والجمعة وقرب الصلاة',
                      'Prioritizes morning, evening, Friday and nearby prayer time',
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
                Text(
                  t('نوع المحتوى', 'Content types'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
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
        ],
      ),
    );

    return Scaffold(
      body: dark
          ? DecoratedBox(
              decoration: const BoxDecoration(
                gradient: AppColors.appBackgroundGradient,
              ),
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

class _NafahatOnboarding extends StatefulWidget {
  final bool isArabic;
  final Future<void> Function() onDone;

  const _NafahatOnboarding({
    required this.isArabic,
    required this.onDone,
  });

  @override
  State<_NafahatOnboarding> createState() => _NafahatOnboardingState();
}

class _NafahatOnboardingState extends State<_NafahatOnboarding> {
  final _controller = PageController();
  int _index = 0;

  String t(String ar, String en) => widget.isArabic ? ar : en;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pages = [
      (
        Icons.auto_awesome_rounded,
        t('نفحة في وقتها', 'A reflection at the right time'),
        t(
          'منيب يعرض لك آية أو حديثاً أو ذكراً أو تذكيراً قصيراً فوق التطبيقات.',
          'Munib can show a verse, hadith, dhikr or short reflection above other apps.',
        ),
      ),
      (
        Icons.touch_app_rounded,
        t('أنت من يخفيها', 'You decide when it leaves'),
        t(
          'النفحة لا تختفي وحدها. افتحها أو حرّكها، واسحبها إلى علامة × عندما تريد إخفاءها.',
          'A Nafha never disappears on its own. Open or move it, then drag it to × when you want to hide it.',
        ),
      ),
      (
        Icons.offline_bolt_rounded,
        t('محتوى جاهز بلا انتظار', 'Ready with no waiting'),
        t(
          'المحتوى ومصدره وفائدته أو تفسيره مجهز مسبقاً، لذلك يظهر مباشرة بدون شاشة تحميل.',
          'The content, source and prepared benefit or explanation are ready in advance, so they appear instantly with no loading screen.',
        ),
      ),
    ];

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: pages.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (context, index) {
                final page = pages[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 128,
                        height: 128,
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: .12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(page.$1, size: 58, color: scheme.primary),
                      ),
                      const SizedBox(height: 34),
                      Text(
                        page.$2,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        page.$3,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(height: 1.7),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              pages.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: index == _index ? 26 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: index == _index
                      ? scheme.primary
                      : scheme.onSurface.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 28),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  if (_index < pages.length - 1) {
                    await _controller.nextPage(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                    );
                  } else {
                    await widget.onDone();
                  }
                },
                child: Text(
                  _index == pages.length - 1
                      ? t('ابدأ', 'Start')
                      : t('التالي', 'Next'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropRow extends StatelessWidget {
  final String label;
  final int value;
  final List<int> values;
  final String suffix;
  final ValueChanged<int> onChanged;

  const _DropRow({
    required this.label,
    required this.value,
    required this.values,
    required this.suffix,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        DropdownButton<int>(
          value: value,
          items: values
              .map(
                (v) => DropdownMenuItem(
                  value: v,
                  child: Text('$v $suffix'),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: dark ? AppColors.heroGradient : null,
        color: dark ? null : scheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: dark
              ? AppColors.gold.withValues(alpha: .28)
              : scheme.outline,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 22,
            offset: const Offset(0, 10),
            color: scheme.shadow.withValues(alpha: dark ? .18 : .08),
          ),
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
                  color: dark
                      ? const Color(0xFF0B1F3A)
                      : scheme.primary.withValues(alpha: .12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: dark ? AppColors.gold : scheme.primary,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: dark ? AppColors.gold : scheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  isArabic ? 'نفحة جديدة' : 'New reflection',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: dark ? Colors.white : scheme.onSurface,
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
            style: theme.textTheme.titleLarge?.copyWith(
              color: dark ? Colors.white : scheme.onSurface,
              height: 1.6,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isArabic ? 'الرعد: 28' : 'Quran 13:28',
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
            style: theme.textTheme.bodySmall?.copyWith(
              color: dark ? AppColors.gold : scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
