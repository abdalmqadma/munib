import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../providers/prayer_provider.dart';

class MunibLottieWidget extends StatelessWidget {
  const MunibLottieWidget({super.key});

  String _getLottieAsset(String prayerName) {
    switch (prayerName.toLowerCase()) {
      case 'fajr':
        return 'assets/lottie/fajr.json';
      case 'sunrise':
        return 'assets/lottie/sunrise.json';
      case 'dhuhr':
        return 'assets/lottie/dhuhr.json';
      case 'asr':
        return 'assets/lottie/asr.json';
      case 'maghrib':
        return 'assets/lottie/maghrib.json';
      case 'isha':
        return 'assets/lottie/isha.json';
      default:
        return 'assets/lottie/fajr.json';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PrayerProvider>(
      builder: (context, provider, child) {
        final nextPrayer = provider.nextPrayerName;
        
        return Container(
          width: double.infinity,
          height: 250,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(35),
            color: Colors.black, // Fallback color
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(35),
            child: Stack(
              children: [
                // 1. Lottie Animation Background
                Positioned.fill(
                  child: Lottie.asset(
                    _getLottieAsset(nextPrayer),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      // Placeholder if file is missing
                      return Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF0D1B2A), Color(0xFF1B263B)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.auto_awesome, color: Colors.white12, size: 100),
                        ),
                      );
                    },
                  ),
                ),

                // 2. Glassy Overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.2),
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),

                // 3. Content
                Padding(
                  padding: const EdgeInsets.all(25.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nextPrayer.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                            ),
                          ),
                          const Text(
                            "الصلاة القادمة • Next Prayer",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      // Countdown Timer
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timer_outlined, color: Color(0xFFFFD166), size: 22),
                            const SizedBox(width: 12),
                            Text(
                              provider.timeLeftFormatted,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
