import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;

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

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: isDark ? AppColors.getGradientForTime(prayer) : null,
          color: isDark ? null : scheme.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isDark ? AppColors.border : scheme.outline,
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: isDark ? .16 : .08),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.goldSoft
                        : scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _iconForPrayer(prayer),
                    color: isDark ? AppColors.gold : scheme.primary,
                  ),
                ),
                const Spacer(),
                Text(
                  context.tr('nextPrayer'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.textSecondary
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              _localizedPrayer(context, prayer),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: isDark ? AppColors.textPrimary : scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              provider.timeLeftFormatted,
              textDirection: TextDirection.ltr,
              style: theme.textTheme.displaySmall?.copyWith(
                color: isDark ? AppColors.textPrimary : scheme.onSurface,
                fontWeight: FontWeight.w400,
                letterSpacing: 1.2,
              ),
            ),
            if (locations.isNotEmpty) ...[
              const SizedBox(height: 18),
              Divider(
                color: (isDark ? Colors.white : scheme.onSurface)
                    .withValues(alpha: .12),
                height: 1,
              ),
              const SizedBox(height: 12),
              ...locations.map((location) {
                final next = _nextPrayerForLocation(location);
                if (next == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${location.name} · ${_localizedPrayer(context, next.name)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        provider.formatPrayerTime(next.time),
                        textDirection: TextDirection.ltr,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.gold : scheme.primary,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      );
    });
  }

  _LocationPrayer? _nextPrayerForLocation(SavedImsakiaLocation location) {
    if (location.prayers.isEmpty) return null;

    tz.Location? locationZone;
    DateTime now;
    if (location.timezone.trim().isNotEmpty) {
      try {
        locationZone = tz.getLocation(location.timezone);
        now = tz.TZDateTime.now(locationZone);
      } catch (_) {
        now = DateTime.now();
      }
    } else {
      now = DateTime.now();
    }

    PrayerDay? findDay(DateTime date) {
      final key = DateFormat('yyyy-MM-dd').format(date);
      for (final day in location.prayers) {
        if (day.date == key) return day;
      }
      return null;
    }

    DateTime parse(String raw, String prayerName, DateTime date) {
      final parsed = DateFormat('HH:mm').parse(raw.trim());
      var hour = parsed.hour;
      if (['Asr', 'Maghrib', 'Isha'].contains(prayerName) && hour < 12) {
        hour += 12;
      }
      if (prayerName == 'Dhuhr' && hour < 10) hour += 12;
      final activeZone = locationZone;
      if (activeZone != null) {
        return tz.TZDateTime(
          activeZone,
          date.year,
          date.month,
          date.day,
          hour,
          parsed.minute,
        );
      }
      return DateTime(date.year, date.month, date.day, hour, parsed.minute);
    }

    final today = findDay(now);
    if (today != null) {
      final prayers = <String, String>{
        'Fajr': today.fajr,
        'Dhuhr': today.dhuhr,
        'Asr': today.asr,
        'Maghrib': today.maghrib,
        'Isha': today.isha,
      };
      for (final entry in prayers.entries) {
        try {
          if (parse(entry.value, entry.key, now).isAfter(now)) {
            return _LocationPrayer(entry.key, entry.value);
          }
        } catch (_) {}
      }
    }

    final tomorrow = now.add(const Duration(days: 1));
    final tomorrowDay = findDay(tomorrow);
    if (tomorrowDay != null) {
      return _LocationPrayer('Fajr', tomorrowDay.fajr);
    }
    return null;
  }

  IconData _iconForPrayer(String prayer) {
    switch (prayer.toLowerCase()) {
      case 'fajr':
        return Icons.wb_twilight_outlined;
      case 'dhuhr':
        return Icons.light_mode_outlined;
      case 'asr':
        return Icons.sunny_snowing;
      case 'maghrib':
        return Icons.wb_twilight_rounded;
      case 'isha':
        return Icons.nightlight_round;
      default:
        return Icons.schedule_rounded;
    }
  }

  String _localizedPrayer(BuildContext context, String prayer) {
    switch (prayer.toLowerCase()) {
      case 'fajr':
        return context.tr('fajr');
      case 'sunrise':
        return context.tr('sunrise');
      case 'dhuhr':
        return context.tr('dhuhr');
      case 'asr':
        return context.tr('asr');
      case 'maghrib':
        return context.tr('maghrib');
      case 'isha':
        return context.tr('isha');
      default:
        return prayer;
    }
  }
}

class _LocationPrayer {
  final String name;
  final String time;

  const _LocationPrayer(this.name, this.time);
}
