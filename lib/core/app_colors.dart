import 'package:flutter/material.dart';

/// Single source of truth for Munib's visual system.
///
/// Do not hard-code app colors inside screens/widgets. Add semantic colors here
/// and consume them directly or through [Theme.of(context).colorScheme].
class AppColors {
  AppColors._();

  // Core canvas
  static const Color background = Color(0xFF09131D);
  static const Color backgroundDeep = Color(0xFF071019);
  static const Color surface = Color(0xFF102131);
  static const Color surfaceElevated = Color(0xFF152838);
  static const Color surfaceSoft = Color(0xFF1A2D3D);

  // Reference-design glass treatment
  static const Color glass = Color(0x141FFFFFF);
  static const Color glassStrong = Color(0x1FFFFFFF);
  static const Color border = Color(0x1AFFFFFF);
  static const Color divider = Color(0x12FFFFFF);

  // Brand accent
  static const Color gold = Color(0xFFD9AD68);
  static const Color goldSoft = Color(0x33D9AD68);
  static const Color goldMuted = Color(0xFF9D8156);

  // Semantic accents
  static const Color blue = Color(0xFF315C78);
  static const Color blueSoft = Color(0x33315C78);
  static const Color red = Color(0xFFE46C64);
  static const Color success = Color(0xFF65A98A);

  // Text hierarchy
  static const Color textPrimary = Color(0xFFF3EFE7);
  static const Color textSecondary = Color(0xFFA9B0B5);
  static const Color textMuted = Color(0xFF697783);
  static const Color textDisabled = Color(0xFF45535E);

  // Compatibility aliases used by existing widgets.
  static const Color primary = gold;
  static const Color accent = gold;

  // Home/background gradients based on the supplied Munib reference.
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
    colors: [
      Color(0xFF17394D),
      Color(0xFF113247),
      Color(0xFF102739),
    ],
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

  static LinearGradient getGradientForTime(String prayer) {
    return getHeroGradient(prayer);
  }
}
