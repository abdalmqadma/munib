import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_strings.dart';
import '../../data/services/azkar_data.dart';
import '../providers/prayer_provider.dart';

class AzkarScreen extends StatelessWidget {
  const AzkarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isEn = context.watch<PrayerProvider>().isEnglish;
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            context.tr('azkar'),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          bottom: TabBar(
            isScrollable: true,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            indicatorColor: theme.colorScheme.primary,
            dividerColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            tabs: [
              _AzkarTab(title: isEn ? 'Morning' : 'الصباح'),
              _AzkarTab(title: isEn ? 'Evening' : 'المساء'),
              _AzkarTab(title: isEn ? 'After Prayer' : 'بعد الصلاة'),
              _AzkarTab(title: isEn ? 'Sleep' : 'النوم'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            AzkarList(category: 'Morning', isEn: isEn),
            AzkarList(category: 'Evening', isEn: isEn),
            AzkarList(category: 'After Prayer', isEn: isEn),
            AzkarList(category: 'Sleep', isEn: isEn),
          ],
        ),
      ),
    );
  }
}

class _AzkarTab extends StatelessWidget {
  final String title;
  const _AzkarTab({required this.title});

  @override
  Widget build(BuildContext context) => Tab(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: Text(title),
        ),
      );
}

class AzkarList extends StatefulWidget {
  final String category;
  final bool isEn;

  const AzkarList({
    super.key,
    required this.category,
    required this.isEn,
  });

  @override
  State<AzkarList> createState() => _AzkarListState();
}

class _AzkarListState extends State<AzkarList> {
  bool _loading = true;
  List<_AzkarProgressItem> _items = const [];

  String get _dayKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  @override
  void didUpdateWidget(covariant AzkarList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category) _loadProgress();
  }

  String _progressKey(int originalIndex) =>
      'azkar_progress_v1:$_dayKey:${widget.category}:$originalIndex';

  Future<void> _loadProgress() async {
    if (mounted) setState(() => _loading = true);
    final source = AzkarData.allAzkar[widget.category] ?? const [];
    final prefs = await SharedPreferences.getInstance();
    final loaded = <_AzkarProgressItem>[];

    for (var i = 0; i < source.length; i++) {
      final azkar = Map<String, dynamic>.from(source[i]);
      final target = (azkar['count'] as num?)?.toInt() ?? 1;
      final count = (prefs.getInt(_progressKey(i)) ?? 0).clamp(0, target);
      if (count < target) {
        loaded.add(
          _AzkarProgressItem(
            id: i,
            data: azkar,
            currentCount: count,
          ),
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _items = loaded;
      _loading = false;
    });
  }

  Future<void> _saveCount(int id, int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_progressKey(id), count);
  }

  Future<void> _complete(_AzkarProgressItem item) async {
    final target = (item.data['count'] as num?)?.toInt() ?? 1;
    await _saveCount(item.id, target);
    if (!mounted) return;
    setState(() => _items.removeWhere((candidate) => candidate.id == item.id));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return Center(
        child: Text(
          context.tr('azkarCompleted'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      );
    }

    return ListView.builder(
      key: PageStorageKey(widget.category),
      padding: const EdgeInsets.all(20),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return _StaggeredEntrance(
          key: ValueKey('${widget.category}-${item.id}'),
          index: index,
          child: AzkarCard(
            azkar: item.data,
            isEn: widget.isEn,
            initialCount: item.currentCount,
            onCountChanged: (count) => _saveCount(item.id, count),
            onCompleted: () => _complete(item),
          ),
        );
      },
    );
  }
}

class _AzkarProgressItem {
  final int id;
  final Map<String, dynamic> data;
  final int currentCount;

  const _AzkarProgressItem({
    required this.id,
    required this.data,
    required this.currentCount,
  });
}

class _StaggeredEntrance extends StatelessWidget {
  final int index;
  final Widget child;

  const _StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + (index.clamp(0, 8) * 75)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset((1 - value) * 54, 0),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class AzkarCard extends StatefulWidget {
  final Map<String, dynamic> azkar;
  final bool isEn;
  final int initialCount;
  final ValueChanged<int> onCountChanged;
  final VoidCallback onCompleted;

  const AzkarCard({
    super.key,
    required this.azkar,
    required this.isEn,
    required this.initialCount,
    required this.onCountChanged,
    required this.onCompleted,
  });

  @override
  State<AzkarCard> createState() => _AzkarCardState();
}

class _AzkarCardState extends State<AzkarCard> {
  late int _currentCount;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _currentCount = widget.initialCount;
  }

  Future<void> _setCount(int value) async {
    if (_leaving) return;
    final target = (widget.azkar['count'] as num?)?.toInt() ?? 1;
    final next = value.clamp(0, target);
    setState(() => _currentCount = next);
    await widget.onCountChanged(next);

    if (next >= target) {
      if (!mounted) return;
      setState(() => _leaving = true);
      await Future<void>.delayed(const Duration(milliseconds: 260));
      widget.onCompleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final target = (widget.azkar['count'] as num?)?.toInt() ?? 1;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 240),
      opacity: _leaving ? 0 : 1,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInCubic,
        offset: _leaving ? const Offset(-.18, 0) : Offset.zero,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: scheme.outline),
          ),
          child: Column(
            children: [
              Text(
                widget.azkar['text']?.toString() ?? '',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: theme.textTheme.headlineSmall?.copyWith(
                  height: 1.75,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.isEn
                    ? '$target ${target == 1 ? 'time' : 'times'}'
                    : (widget.azkar['subtitle']?.toString() ?? ''),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: target == 0 ? 0 : _currentCount / target,
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: _currentCount > 0
                        ? () => _setCount(_currentCount - 1)
                        : null,
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  const Spacer(),
                  Text(
                    '$_currentCount / $target',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton.filled(
                    onPressed: () => _setCount(_currentCount + 1),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
