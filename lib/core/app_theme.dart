import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark => _buildTheme(Brightness.dark);
  static ThemeData get light => _buildTheme(Brightness.light);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final background = isDark ? AppColors.background : AppColors.lightBackground;
    final backgroundDeep =
        isDark ? AppColors.backgroundDeep : AppColors.lightBackgroundDeep;
    final surface = isDark ? AppColors.surface : AppColors.lightSurface;
    final surfaceElevated =
        isDark ? AppColors.surfaceElevated : AppColors.lightSurfaceElevated;
    final textPrimary =
        isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final border = isDark ? AppColors.border : AppColors.lightBorder;
    final divider = isDark ? AppColors.divider : AppColors.lightDivider;
    final glass = isDark ? AppColors.glass : AppColors.lightGlass;
    const primary = AppColors.teal;

    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      surface: surface,
    ).copyWith(
      primary: primary,
      onPrimary: AppColors.backgroundDeep,
      primaryContainer:
          isDark ? AppColors.tealSoft : AppColors.lightSurfaceSoft,
      onPrimaryContainer: isDark ? AppColors.tealHighlight : AppColors.blue,
      secondary: isDark ? AppColors.tealGlow : AppColors.blue,
      onSecondary: isDark ? AppColors.backgroundDeep : Colors.white,
      surface: surface,
      onSurface: textPrimary,
      error: AppColors.red,
      outline: border,
      outlineVariant: divider,
      shadow: isDark ? AppColors.tealGlow : const Color(0x260B0D2E),
    );

    final textTheme = TextTheme(
      displayLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      displayMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      displaySmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      headlineLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
      titleSmall: TextStyle(color: textSecondary, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(color: textPrimary),
      bodyMedium: TextStyle(color: textSecondary),
      bodySmall: TextStyle(color: textMuted),
      labelLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      labelMedium: TextStyle(color: textSecondary, fontWeight: FontWeight.w500),
      labelSmall: TextStyle(color: textMuted, fontWeight: FontWeight.w500),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      cardColor: surface,
      dividerColor: divider,
      splashColor: AppColors.tealSoft,
      highlightColor: Colors.transparent,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: textSecondary),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: AppColors.backgroundDeep,
          shadowColor: isDark
              ? AppColors.tealGlow.withValues(alpha: .58)
              : Colors.transparent,
          elevation: isDark ? 4 : 0,
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: AppColors.backgroundDeep,
          shadowColor: isDark
              ? AppColors.tealGlow.withValues(alpha: .52)
              : Colors.transparent,
          elevation: isDark ? 3 : 0,
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? AppColors.tealHighlight : AppColors.blue,
          minimumSize: const Size(48, 52),
          side: BorderSide(color: isDark ? AppColors.teal : border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glass,
        hintStyle: TextStyle(color: textMuted),
        labelStyle: TextStyle(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: backgroundDeep,
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
        selectedIconTheme: const IconThemeData(color: primary),
        unselectedIconTheme: IconThemeData(color: textMuted),
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: backgroundDeep,
        indicatorColor:
            isDark ? AppColors.tealSoft : AppColors.lightSurfaceSoft,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(color: textSecondary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceElevated,
        contentTextStyle: TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
      ),
    );
  }
}
