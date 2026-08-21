import 'package:flutter/material.dart';

/// Single source of truth for Munib's visual system.
/// Do not hard-code app colors inside screens/widgets.
class AppColors {
  AppColors._();

  // Dark theme
  static const Color background = Color(0xFF09131D);
  static const Color backgroundDeep = Color(0xFF071019);
  static const Color surface = Color(0xFF102131);
  static const Color surfaceElevated = Color(0xFF152838);
  static const Color surfaceSoft = Color(0xFF1A2D3D);
  static const Color glass = Color(0x14FFFFFF);
  static const Color glassStrong = Color(0x1FFFFFFF);
  static const Color border = Color(0x1AFFFFFF);
  static const Color divider = Color(0x12FFFFFF);
  static const Color textPrimary = Color(0xFFF3EFE7);
  static const Color textSecondary = Color(0xFFA9B0B5);
  static const Color textMuted = Color(0xFF697783);
  static const Color textDisabled = Color(0xFF45535E);

  // Light theme
  static const Color lightBackground = Color(0xFFF4F1EA);
  static const Color lightBackgroundDeep = Color(0xFFECE7DD);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF8F5EF);
  static const Color lightSurfaceSoft = Color(0xFFEAE4D9);
  static const Color lightGlass = Color(0xBFFFFFFF);
  static const Color lightBorder = Color(0x1F102131);
  static const Color lightDivider = Color(0x14102131);
  static const Color lightTextPrimary = Color(0xFF17232D);
  static const Color lightTextSecondary = Color(0xFF586570);
  static const Color lightTextMuted = Color(0xFF83909A);

  // Brand accent
  static const Color gold = Color(0xFFD9AD68);
  static const Color goldSoft = Color(0x33D9AD68);
  static const Color goldMuted = Color(0xFF9D8156);

  // Semantic accents
  static const Color blue = Color(0xFF315C78);
  static const Color blueSoft = Color(0x33315C78);
  static const Color red = Color(0xFFE46C64);
  static const Color success = Color(0xFF65A98A);

  static const Color primary = gold;
  static const Color accent = gold;

  static const List<Color> nightGradient = [
    Color(0xFF17242B),
    Color(0xFF0B1825),
    Color(0xFF07131F),
  ];

  static const List<Color> sunsetGradient = [
    Color(0xFF2B2824),
    Color(0xFF17242A),
    Color(0xFF0A1722),
  ];

  static const List<Color> daylightGradient = [
    Color(0xFF26383D),
    Color(0xFF142735),
    Color(0xFF0A1723),
  ];

  static const LinearGradient appBackgroundGradient = LinearGradient(
    colors: nightGradient,
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0, 0.42, 1],
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF17394D), Color(0xFF113247), Color(0xFF102739)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Color getBackgroundColor(String nextPrayer) {
    switch (nextPrayer.toLowerCase()) {
      case 'maghrib':
        return const Color(0xFF111A20);
      case 'isha':
      case 'fajr':
        return backgroundDeep;
      default:
        return background;
    }
  }

  static LinearGradient getHeroGradient(String nextPrayer) {
    if (nextPrayer.toLowerCase() == 'maghrib') {
      return const LinearGradient(
        colors: [Color(0xFF26302F), Color(0xFF153044), Color(0xFF102535)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return heroGradient;
  }

  static LinearGradient getGradientForTime(String prayer) => getHeroGradient(prayer);
}
