import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_strings.dart';
import '../../data/models/prayer_day.dart';
import '../providers/prayer_provider.dart';

class MunibUltimateWidget extends StatelessWidget {
  const MunibUltimateWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PrayerProvider>(builder: (context, provider, child) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      final isDark = theme.brightness == Brightness.dark;
      final prayer = provider.nextPrayerName;
      final locations = provider.savedLocations.take(2).toList();
      final date = provider.currentDay?.date;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: isDark ? AppColors.getGradientForTime(prayer) : null,
          color: isDark ? null : scheme.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: isDark ? AppColors.border : scheme.outline),
          boxShadow: [BoxShadow(color: scheme.shadow.withValues(alpha: isDark ? .16 : .08), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: isDark ? AppColors.goldSoft : scheme.primaryContainer, borderRadius: BorderRadius.circular(14)),
              child: Icon(_iconForPrayer(prayer), color: isDark ? AppColors.gold : scheme.primary),
            ),
            const Spacer(),
            Text(context.tr('nextPrayer'), style: theme.textTheme.bodyMedium?.copyWith(color: isDark ? AppColors.textSecondary : scheme.onSurfaceVariant)),
          ]),
          const SizedBox(height: 22),
          Text(_localizedPrayer(context, prayer), style: theme.textTheme.headlineMedium?.copyWith(color: isDark ? AppColors.textPrimary : scheme.onSurface, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(provider.timeLeftFormatted, textDirection: TextDirection.ltr, style: theme.textTheme.displaySmall?.copyWith(color: isDark ? AppColors.textPrimary : scheme.onSurface, fontWeight: FontWeight.w400, letterSpacing: 1.2)),
          if (locations.isNotEmpty && date != null) ...[
            const SizedBox(height: 18),
            Divider(color: (isDark ? Colors.white : scheme.onSurface).withValues(alpha: .12), height: 1),
            const SizedBox(height: 12),
            ...locations.map((location) {
              PrayerDay? day;
              for (final item in location.prayers) {
                if (item.date == date) { day = item; break; }
              }
              if (day == null) return const SizedBox.shrink();
              final raw = _timeForPrayer(day, prayer);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: Text(location.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                  Text(provider.formatPrayerTime(raw), textDirection: TextDirection.ltr, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: isDark ? AppColors.gold : scheme.primary)),
                ]),
              );
            }),
          ],
        ]),
      );
    });
  }

  String _timeForPrayer(PrayerDay day, String prayer) {
    switch (prayer.toLowerCase()) {
      case 'fajr': return day.fajr;
      case 'sunrise': return day.sunrise;
      case 'dhuhr': return day.dhuhr;
      case 'asr': return day.asr;
      case 'maghrib': return day.maghrib;
      case 'isha': return day.isha;
      default: return '';
    }
  }

  IconData _iconForPrayer(String prayer) {
    switch (prayer.toLowerCase()) {
      case 'fajr': return Icons.wb_twilight_outlined;
      case 'sunrise': return Icons.wb_sunny_outlined;
      case 'dhuhr': return Icons.light_mode_outlined;
      case 'asr': return Icons.sunny_snowing;
      case 'maghrib': return Icons.wb_twilight_rounded;
      case 'isha': return Icons.nightlight_round;
      default: return Icons.schedule_rounded;
    }
  }

  String _localizedPrayer(BuildContext context, String prayer) {
    switch (prayer.toLowerCase()) {
      case 'fajr': return context.tr('fajr');
      case 'sunrise': return context.tr('sunrise');
      case 'dhuhr': return context.tr('dhuhr');
      case 'asr': return context.tr('asr');
      case 'maghrib': return context.tr('maghrib');
      case 'isha': return context.tr('isha');
      default: return prayer;
    }
  }
}
