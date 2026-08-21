import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
          title: Text(context.tr('azkar'), style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
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
        body: TabBarView(children: [
          AzkarList(category: 'Morning', isEn: isEn),
          AzkarList(category: 'Evening', isEn: isEn),
          AzkarList(category: 'After Prayer', isEn: isEn),
          AzkarList(category: 'Sleep', isEn: isEn),
        ]),
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
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: Theme.of(context).colorScheme.outline)),
      child: Text(title),
    ),
  );
}

class AzkarList extends StatefulWidget {
  final String category;
  final bool isEn;
  const AzkarList({super.key, required this.category, required this.isEn});
  @override
  State<AzkarList> createState() => _AzkarListState();
}

class _AzkarListState extends State<AzkarList> {
  late List<Map<String, dynamic>> _items;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(covariant AzkarList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category) _reset();
  }

  void _reset() {
    _items = List<Map<String, dynamic>>.from(AzkarData.allAzkar[widget.category] ?? const []);
  }

  void _complete(int index) {
    if (index < 0 || index >= _items.length) return;
    setState(() => _items.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return Center(child: Text(context.tr('azkarCompleted'), style: Theme.of(context).textTheme.titleLarge));
    }
    return ListView.builder(
      key: PageStorageKey(widget.category),
      padding: const EdgeInsets.all(20),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return _StaggeredEntrance(
          key: ValueKey('${widget.category}-${item['text']}'),
          index: index,
          child: AzkarCard(
            azkar: item,
            isEn: widget.isEn,
            onCompleted: () => _complete(index),
          ),
        );
      },
    );
  }
}

class _StaggeredEntrance extends StatelessWidget {
  final int index;
  final Widget child;
  const _StaggeredEntrance({super.key, required this.index, required this.child});
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + (index.clamp(0, 8) * 75)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset((1 - value) * 54, 0), child: child),
      ),
      child: child,
    );
  }
}

class AzkarCard extends StatefulWidget {
  final Map<String, dynamic> azkar;
  final bool isEn;
  final VoidCallback onCompleted;
  const AzkarCard({super.key, required this.azkar, required this.isEn, required this.onCompleted});
  @override
  State<AzkarCard> createState() => _AzkarCardState();
}

class _AzkarCardState extends State<AzkarCard> {
  int _currentCount = 0;
  bool _leaving = false;

  void _increment() {
    if (_leaving) return;
    final target = (widget.azkar['count'] as num?)?.toInt() ?? 1;
    final next = _currentCount + 1;
    setState(() => _currentCount = next.clamp(0, target));
    if (next >= target) {
      setState(() => _leaving = true);
      Future.delayed(const Duration(milliseconds: 260), widget.onCompleted);
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
          child: Column(children: [
            Text(
              widget.azkar['text']?.toString() ?? '',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(height: 1.75, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(widget.isEn ? '$target times' : (widget.azkar['subtitle']?.toString() ?? ''), style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: target == 0 ? 0 : _currentCount / target, minHeight: 5),
            ),
            const SizedBox(height: 18),
            Row(children: [
              IconButton.filledTonal(onPressed: _currentCount > 0 ? () => setState(() => _currentCount--) : null, icon: const Icon(Icons.remove_rounded)),
              const Spacer(),
              Text('$_currentCount / $target', style: theme.textTheme.titleLarge?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800)),
              const Spacer(),
              IconButton.filled(onPressed: _increment, icon: const Icon(Icons.add_rounded)),
            ]),
          ]),
        ),
      ),
    );
  }
}
