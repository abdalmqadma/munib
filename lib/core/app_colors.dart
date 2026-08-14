import 'package:flutter/material.dart';

class AppColors {
  // Primary Theme Colors (Night Mode - Default)
  static const Color background = Color(0xFF071019);
  static const Color surface = Color(0xFF0B1724);
  static const Color glass = Color(0x0DFFFFFF);
  static const Color border = Color(0x0DFFFFFF);
  
  // Dynamic Accent Colors
  static const Color gold = Color(0xFFFFD166);
  static const Color blue = Color(0xFF1E88E5);
  static const Color red = Color(0xFFFF5252);

  // Missing properties requested by widgets
  static const Color primary = Color(0xFF1E88E5);
  static const Color accent = Color(0xFFFFD166);
  
  // Gradients for different times (Night/Sunset/Day)
  static const List<Color> nightGradient = [Color(0xFF0D1B2A), Color(0xFF1B263B)];
  static const List<Color> sunsetGradient = [Color(0xFF1A1210), Color(0xFF2D1F1A)];
  static const List<Color> daylightGradient = [Color(0xFF1A3C5A), Color(0xFF2E5B82)];

  static Color getBackgroundColor(String nextPrayer) {
    switch (nextPrayer.toLowerCase()) {
      case 'maghrib':
        return const Color(0xFF1A1210);
      case 'isha':
      case 'fajr':
        return background;
      default:
        return const Color(0xFF0D1B2A);
    }
  }

  static LinearGradient getHeroGradient(String nextPrayer) {
    if (nextPrayer.toLowerCase() == 'maghrib') {
      return const LinearGradient(
        colors: [Color(0xFF2D1F1A), Color(0xFF1A1210)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return LinearGradient(
      colors: [Color(0x0DFFFFFF), Color(0x03FFFFFF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  // Compatibility method for HeroCard
  static LinearGradient getGradientForTime(String prayer) {
    return getHeroGradient(prayer);
  }
}
