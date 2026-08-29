import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/prayer_provider.dart';
import '../../core/app_colors.dart';

class HeroCard extends StatelessWidget {
  const HeroCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PrayerProvider>(
      builder: (context, provider, child) {
        final nextPrayer = provider.nextPrayerName;
        final now = provider.currentLocationTime;
        final isSunset = nextPrayer.toLowerCase() == 'maghrib';
        final cardColor = isSunset ? const Color(0xFF2D1F1A) : Colors.white.withOpacity(0.05);

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(35),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              Text(
                DateFormat('HH:mm').format(now),
                style: const TextStyle(color: Colors.white, fontSize: 72, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                DateFormat('EEEE, d MMMM', 'ar').format(now),
                style: const TextStyle(color: Colors.white38, fontSize: 14),
              ),
            ],
          ),
        );
      },
    );
  }
}
