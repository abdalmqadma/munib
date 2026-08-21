import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_strings.dart';
import '../../data/services/azkar_data.dart';
import '../providers/prayer_provider.dart';

class AzkarScreen extends StatelessWidget {
  const AzkarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrayerProvider>();
    final isEn = provider.isEnglish;
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            context.tr('azkar'),
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
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
  Widget build(BuildContext context) {
    return Tab(
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
}

class AzkarList extends StatelessWidget {
  final String category;
  final bool isEn;
  const AzkarList({super.key, required this.category, required this.isEn});

  @override
  Widget build(BuildContext context) {
    final azkarData = AzkarData.allAzkar[category] ?? [];
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: azkarData.length,
      itemBuilder: (context, index) => AzkarCard(azkar: azkarData[index], isEn: isEn),
    );
  }
}

class AzkarCard extends StatefulWidget {
  final Map<String, dynamic> azkar;
  final bool isEn;
  const AzkarCard({super.key, required this.azkar, required this.isEn});

  @override
  State<AzkarCard> createState() => _AzkarCardState();
}

class _AzkarCardState extends State<AzkarCard> {
  int _currentCount = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bool isCompleted = _currentCount >= widget.azkar['count'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isCompleted ? scheme.primary.withValues(alpha: .45) : scheme.outline,
        ),
      ),
      child: Column(
        children: [
          Text(
            widget.azkar['text'],
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(height: 1.6, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            widget.isEn ? (isCompleted ? 'Completed' : 'Once') : widget.azkar['subtitle'],
            style: theme.textTheme.bodySmall?.copyWith(
              color: isCompleted ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              _smallIcon(context, Icons.hexagon_outlined),
              const SizedBox(width: 10),
              _smallIcon(context, Icons.favorite_border),
              const Spacer(),
              if (!isCompleted)
                Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      _counterBtn(context, Icons.remove, () {
                        if (_currentCount > 0) setState(() => _currentCount--);
                      }),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          '$_currentCount',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _counterBtn(context, Icons.add, () {
                        if (_currentCount < widget.azkar['count']) setState(() => _currentCount++);
                      }),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: scheme.primary.withValues(alpha: .3)),
                  ),
                  child: Text(
                    "${widget.azkar['count']}/${widget.azkar['count']} ✓",
                    style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _smallIcon(BuildContext context, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: scheme.onSurfaceVariant, size: 20),
    );
  }

  Widget _counterBtn(BuildContext context, IconData icon, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(icon, color: scheme.primary, size: 20),
      ),
    );
  }
}
