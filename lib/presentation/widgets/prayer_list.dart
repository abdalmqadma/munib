import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/prayer_provider.dart';
import '../../core/app_colors.dart';

class PrayerList extends StatelessWidget {
  const PrayerList({super.key});

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
            final isNext = provider.nextPrayerName == prayer['key'];
            
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
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
                ],
              ),
            );
          },
        );
      },
    );
  }
}
