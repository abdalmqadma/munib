import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_strings.dart';
import '../../data/models/prayer_day.dart';
import '../providers/prayer_provider.dart';

class ReviewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> initialData;
  const ReviewScreen({super.key, required this.initialData});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late List<Map<String, dynamic>> _data;
  int _currentDayIndex = 0;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final reviewIndex = _data.indexWhere((day) => day['review_required'] == true);
    if (reviewIndex >= 0) _currentDayIndex = reviewIndex;
  }

  void _updateTime(String prayerKey, String newValue) {
    setState(() => _data[_currentDayIndex][prayerKey] = newValue);
  }

  Future<void> _editTime(String key, String currentValue) async {
    final parts = currentValue.split(':');
    if (parts.length != 2) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 0,
        minute: int.tryParse(parts[1]) ?? 0,
      ),
    );
    if (picked != null) {
      _updateTime(
        key,
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrayerProvider>();
    final isEn = provider.isEnglish;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (_data.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(
            isEn ? 'No data to review' : 'لا توجد بيانات للمراجعة',
            style: theme.textTheme.bodyLarge,
          ),
        ),
      );
    }

    final currentDay = _data[_currentDayIndex];
    final currentNeedsReview = currentDay['review_required'] == true;
    final hasReviewRows = _data.any((day) => day['review_required'] == true);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEn ? 'Review prayer times' : 'مراجعة الأوقات'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                isEn ? 'Check the times and edit anything that needs correction' : 'تحقق من الأوقات وعدّل عند الحاجة',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            if (hasReviewRows) ...[
              const SizedBox(height: 14),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: scheme.primary.withValues(alpha: .35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: scheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isEn
                            ? 'One or more days were estimated because the timetable image was unclear. Review the marked day, edit it if needed, or keep the suggested times.'
                            : 'تم تقدير يوم أو أكثر لأن صفًا في صورة الإمساكية لم يُقرأ بوضوح. راجع اليوم المعلّم، وعدّله إذا لزم أو اقبل الأوقات المقترحة.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_data.length > 1)
              SizedBox(
                height: 46,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: _data.length,
                  itemBuilder: (context, index) {
                    final selected = _currentDayIndex == index;
                    final needsReview = _data[index]['review_required'] == true;
                    return Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(
                        selected: selected,
                        avatar: needsReview
                            ? Icon(
                                Icons.warning_amber_rounded,
                                size: 18,
                                color: selected ? scheme.onPrimary : scheme.primary,
                              )
                            : null,
                        label: Text(isEn ? 'Day ${index + 1}' : 'يوم ${index + 1}'),
                        onSelected: (_) => setState(() => _currentDayIndex = index),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: currentNeedsReview ? scheme.primary : scheme.outline,
                    width: currentNeedsReview ? 1.6 : 1,
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    if (currentNeedsReview)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: scheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isEn ? 'Estimated day — please verify' : 'يوم مقدّر — يرجى التحقق منه',
                                style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    _prayerRow(context, context.tr('fajr'), currentDay['fajr'] ?? '--:--', 'fajr', Icons.bedtime_outlined),
                    const Divider(height: 1),
                    _prayerRow(context, context.tr('sunrise'), currentDay['sunrise'] ?? '--:--', 'sunrise', Icons.wb_twilight_outlined),
                    const Divider(height: 1),
                    _prayerRow(context, context.tr('dhuhr'), currentDay['dhuhr'] ?? '--:--', 'dhuhr', Icons.wb_sunny_outlined),
                    const Divider(height: 1),
                    _prayerRow(context, context.tr('asr'), currentDay['asr'] ?? '--:--', 'asr', Icons.light_mode_outlined),
                    const Divider(height: 1),
                    _prayerRow(context, context.tr('maghrib'), currentDay['maghrib'] ?? '--:--', 'maghrib', Icons.sunny_snowing),
                    const Divider(height: 1),
                    _prayerRow(context, context.tr('isha'), currentDay['isha'] ?? '--:--', 'isha', Icons.nightlight_outlined),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final prayers = _data.map((e) => PrayerDay.fromJson(e)).toList();
                    await context.read<PrayerProvider>().setMonthlyPrayers(prayers);
                    if (context.mounted) Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: Text(isEn ? 'Save prayer times' : 'حفظ الأوقات'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _prayerRow(
    BuildContext context,
    String name,
    String time,
    String key,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: scheme.primary),
      ),
      title: Text(name, style: theme.textTheme.titleMedium),
      subtitle: Text(
        time,
        textDirection: TextDirection.ltr,
        style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary),
      ),
      trailing: IconButton(
        onPressed: () => _editTime(key, time),
        icon: const Icon(Icons.edit_outlined),
        color: scheme.primary,
      ),
    );
  }
}
