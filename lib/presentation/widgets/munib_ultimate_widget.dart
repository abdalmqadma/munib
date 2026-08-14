import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../providers/prayer_provider.dart';

class MunibUltimateWidget extends StatefulWidget {
  const MunibUltimateWidget({super.key});

  @override
  State<MunibUltimateWidget> createState() => _MunibUltimateWidgetState();
}

class _MunibUltimateWidgetState extends State<MunibUltimateWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Color> _getColors(String prayer) {
    switch (prayer.toLowerCase()) {
      case 'fajr': return [const Color(0xFF1E3C72), const Color(0xFF2A5298), const Color(0xFFF39292)];
      case 'sunrise': return [const Color(0xFF4CA1AF), const Color(0xFFC4E0E5)];
      case 'dhuhr': return [const Color(0xFF2193B0), const Color(0xFF6DD5ED)];
      case 'asr': return [const Color(0xFFF2994A), const Color(0xFFF2C94C)];
      case 'maghrib': return [const Color(0xFFED213A), const Color(0xFF93291E)];
      case 'isha': return [const Color(0xFF0F2027), const Color(0xFF203A43), const Color(0xFF2C5364)];
      default: return [const Color(0xFF071019), const Color(0xFF1B263B)];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PrayerProvider>(
      builder: (context, provider, child) {
        final prayer = provider.nextPrayerName;
        final isNight = prayer.toLowerCase() == 'isha' || prayer.toLowerCase() == 'fajr';

        return Container(
          width: double.infinity,
          height: 230,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(35),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _getColors(prayer),
            ),
            boxShadow: [
              BoxShadow(
                color: _getColors(prayer).last.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(35),
            child: Stack(
              children: [
                // 1. Twinkling Stars (Only for Night/Fajr)
                if (isNight) ..._buildStars(),

                // 2. Floating Clouds (All times)
                _buildFloatingClouds(),

                // 3. Main Content
                Padding(
                  padding: const EdgeInsets.all(25.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildHeader(prayer),
                          _buildSunMoonIcon(prayer),
                        ],
                      ),
                      const Spacer(),
                      _buildCountdownArea(provider.timeLeftFormatted),
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

  Widget _buildHeader(String prayer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          prayer.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            shadows: [Shadow(blurRadius: 10, color: Colors.black26)],
          ),
        ),
        const Text(
          "الصلاة القادمة • Next Prayer",
          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildCountdownArea(String timeLeft) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, color: Color(0xFFFFD166), size: 20),
          const SizedBox(width: 12),
          Text(
            timeLeft,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSunMoonIcon(String prayer) {
    bool isNight = prayer.toLowerCase() == 'isha' || prayer.toLowerCase() == 'fajr';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isNight ? Icons.nightlight_round : Icons.wb_sunny,
        color: isNight ? Colors.white : const Color(0xFFFFD166),
        size: 32,
      ),
    );
  }

  Widget _buildFloatingClouds() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: _controller.value * 600 - 200,
          top: 40,
          child: Opacity(
            opacity: 0.2,
            child: const Icon(Icons.cloud, color: Colors.white, size: 140),
          ),
        );
      },
    );
  }

  List<Widget> _buildStars() {
    final random = math.Random(10); 
    return List.generate(15, (index) {
      return Positioned(
        top: random.nextDouble() * 120,
        left: random.nextDouble() * 350,
        child: _TwinklingStar(),
      );
    });
  }
}

class _TwinklingStar extends StatefulWidget {
  @override
  State<_TwinklingStar> createState() => _TwinklingStarState();
}

class _TwinklingStarState extends State<_TwinklingStar> with SingleTickerProviderStateMixin {
  late AnimationController _starController;

  @override
  void initState() {
    super.initState();
    _starController = AnimationController(
      vsync: this, 
      duration: Duration(milliseconds: 800 + math.Random().nextInt(1500))
    )..repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _starController,
      child: const Icon(Icons.star, color: Colors.white, size: 4),
    );
  }

  @override
  void dispose() {
    _starController.dispose();
    super.dispose();
  }
}
