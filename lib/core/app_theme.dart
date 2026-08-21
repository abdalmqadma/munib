import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.gold,
      brightness: Brightness.dark,
      surface: AppColors.surface,
    ).copyWith(
      primary: AppColors.gold,
      onPrimary: AppColors.backgroundDeep,
      secondary: AppColors.goldMuted,
      onSecondary: AppColors.textPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.red,
      outline: AppColors.border,
      outlineVariant: AppColors.divider,
    );

    const baseText = TextTheme(
      displayLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      displayMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      displaySmall: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      headlineLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      headlineMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
      titleSmall: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(color: AppColors.textPrimary),
      bodyMedium: TextStyle(color: AppColors.textSecondary),
      bodySmall: TextStyle(color: AppColors.textMuted),
      labelLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      labelMedium: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
      labelSmall: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w500),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Inter',
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      cardColor: AppColors.surface,
      dividerColor: AppColors.divider,
      splashColor: AppColors.goldSoft,
      highlightColor: Colors.transparent,
      textTheme: baseText,
      iconTheme: const IconThemeData(color: AppColors.textSecondary),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.backgroundDeep,
          elevation: 0,
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(48, 52),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.gold),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.glass,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.gold),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.backgroundDeep,
        selectedItemColor: AppColors.gold,
        unselectedItemColor: AppColors.textMuted,
        selectedIconTheme: IconThemeData(color: AppColors.gold),
        unselectedIconTheme: IconThemeData(color: AppColors.textMuted),
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.backgroundDeep,
        indicatorColor: AppColors.goldSoft,
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? const IconThemeData(color: AppColors.gold)
              : const IconThemeData(color: AppColors.textMuted);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? AppColors.gold
                : AppColors.textMuted,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceElevated,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.gold),
    );
  }
}
