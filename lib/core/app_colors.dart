import 'package:flutter/material.dart';

/// Single source of truth for Munib's visual system.
/// Do not hard-code app colors inside screens/widgets.
class AppColors {
  AppColors._();

  // Dark theme — navy + glowing teal
  static const Color background = Color(0xFF0B0D2E);
  static const Color backgroundDeep = Color(0xFF070922);
  static const Color surface = Color(0xFF171A45);
  static const Color surfaceElevated = Color(0xFF1C2056);
  static const Color surfaceSoft = Color(0xFF22285F);
  static const Color glass = Color(0x1836ADA3);
  static const Color glassStrong = Color(0x2445E0D1);
  static const Color border = Color(0x3D36ADA3);
  static const Color divider = Color(0x2436ADA3);
  static const Color textPrimary = Color(0xFFECEFF3);
  static const Color textSecondary = Color(0xFFB9C1CC);
  static const Color textMuted = Color(0xFF8C96A8);
  static const Color textDisabled = Color(0xFF59627A);

  // Light theme — cool white + navy + teal
  static const Color lightBackground = Color(0xFFF6FAFA);
  static const Color lightBackgroundDeep = Color(0xFFEEF5F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF8FCFC);
  static const Color lightSurfaceSoft = Color(0xFFE6F7F5);
  static const Color lightGlass = Color(0xEFFFFFFF);
  static const Color lightBorder = Color(0xFFD9E4E4);
  static const Color lightDivider = Color(0xFFE3ECEC);
  static const Color lightTextPrimary = Color(0xFF1B2230);
  static const Color lightTextSecondary = Color(0xFF6E7785);
  static const Color lightTextMuted = Color(0xFF8F98A5);

  // Brand accent
  static const Color teal = Color(0xFF36ADA3);
  static const Color tealGlow = Color(0xFF45E0D1);
  static const Color tealHighlight = Color(0xFF7FF7EC);
  static const Color tealSoft = Color(0x3336ADA3);
  static const Color tealMuted = Color(0xFF277E78);

  // Backward-compatible aliases. Existing widgets that still refer to the
  // previous gold accent now inherit the new Munib teal identity.
  static const Color gold = teal;
  static const Color goldSoft = tealSoft;
  static const Color goldMuted = tealMuted;

  // Semantic accents
  static const Color blue = Color(0xFF121358);
  static const Color blueSoft = Color(0x33121358);
  static const Color red = Color(0xFFE46C64);
  static const Color success = Color(0xFF36ADA3);

  static const Color primary = teal;
  static const Color accent = teal;

  static const List<Color> nightGradient = [
    Color(0xFF121358),
    Color(0xFF0E103E),
    Color(0xFF0B0D2E),
  ];

  static const List<Color> sunsetGradient = [
    Color(0xFF171A45),
    Color(0xFF121358),
    Color(0xFF0B0D2E),
  ];

  static const List<Color> daylightGradient = [
    Color(0xFF1A2457),
    Color(0xFF121A4B),
    Color(0xFF0B0D2E),
  ];

  static const LinearGradient appBackgroundGradient = LinearGradient(
    colors: nightGradient,
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0, 0.45, 1],
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF171A45), Color(0xFF121358), Color(0xFF0D1038)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Color getBackgroundColor(String nextPrayer) {
    switch (nextPrayer.toLowerCase()) {
      case 'maghrib':
        return const Color(0xFF10133B);
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
        colors: [Color(0xFF1B2053), Color(0xFF13164B), Color(0xFF0D1036)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return heroGradient;
  }

  static LinearGradient getGradientForTime(String prayer) => getHeroGradient(prayer);
}
