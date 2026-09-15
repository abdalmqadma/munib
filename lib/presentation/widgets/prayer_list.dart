import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_colors.dart';
import '../../features/prayer_times/data/prayer_times_service.dart';
import '../providers/prayer_provider.dart';

class PrayerList extends StatelessWidget {
  const PrayerList({super.key});

  Future<void> _openInShiftly(
    BuildContext context,
    PrayerProvider provider,
    String prayer,
  ) async {
    final activeId = provider.activeLocationId;
    if (activeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف مواقيت الصلاة أولًا ثم حاول مجددًا.')),
      );
      return;
    }

    final matches = provider.savedLocations.where((item) => item.id == activeId);
    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديد موقع الإمساكية الحالية.')),
      );
      return;
    }

    final location = matches.first;
    final profile = PrayerCalculationProfile.forLocation(
      latitude: location.latitude,
      longitude: location.longitude,
    );

    final uri = Uri(
      scheme: 'shiftly',
      host: 'prayer-alarm',
      queryParameters: {
        'prayer': prayer,
        'lat': location.latitude.toString(),
        'lon': location.longitude.toString(),
        'method': profile.method.toString(),
        'school': profile.school.toString(),
        if (profile.tune != null) 'tune': profile.tune!,
      },
    );

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ثبّت Shiftly أولًا لاستخدام منبهات الصلاة.')),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح Shiftly على هذا الجهاز.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PrayerProvider>(
      builder: (context, provider, child) {
        if (provider.currentDay == null) {
          return const SizedBox.shrink();
        }

        final prayers = [
          {'name': 'الفجر', 'time': provider.currentDay!.fajr, 'icon': Icons.wb_twilight, 'key': 'Fajr'},
          {'name': 'الشروق', 'time': provider.currentDay!.sunrise, 'icon': Icons.wb_sunny_outlined, 'key': 'Sunrise'},
          {'name': 'الظهر', 'time': provider.currentDay!.dhuhr, 'icon': Icons.wb_sunny, 'key': 'Dhuhr'},
          {'name': 'العصر', 'time': provider.currentDay!.asr, 'icon': Icons.cloud_outlined, 'key': 'Asr'},
          {'name': 'المغرب', 'time': provider.currentDay!.maghrib, 'icon': Icons.wb_twilight_rounded, 'key': 'Maghrib'},
          {'name': 'العشاء', 'time': provider.currentDay!.isha, 'icon': Icons.nightlight_round, 'key': 'Isha'},
        ];

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: prayers.length,
          itemBuilder: (context, index) {
            final prayer = prayers[index];
            final prayerKey = prayer['key'] as String;
            final isNext = provider.nextPrayerName == prayerKey;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsetsDirectional.only(
                start: 20,
                end: 10,
                top: 10,
                bottom: 10,
              ),
              decoration: BoxDecoration(
                color: isNext ? AppColors.blue.withOpacity(0.1) : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isNext ? AppColors.blue : Colors.white10, width: 1),
              ),
              child: Row(
                children: [
                  Icon(prayer['icon'] as IconData, color: isNext ? AppColors.blue : Colors.white38),
                  const SizedBox(width: 20),
                  Text(
                    prayer['name'] as String,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
                      color: isNext ? AppColors.blue : Colors.white70,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    prayer['time'] as String,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
                      color: isNext ? AppColors.blue : Colors.white54,
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'ضبط منبه في Shiftly',
                    onPressed: () => _openInShiftly(context, provider, prayerKey),
                    icon: const Icon(Icons.alarm_add_rounded),
                    color: isNext ? AppColors.blue : Colors.white54,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
