import 'package:flutter/material.dart';
import 'colors.dart';

/// Temas globales para la app: claro y oscuro, con tipografÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­as PRO.
class AppThemes {
  static final ThemeData light = ThemeData(
    brightness: Brightness.light,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.backgroundLight,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      iconTheme: IconThemeData(color: AppColors.primary),
      titleTextStyle: TextStyle(
        color: AppColors.primary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      elevation: 1.8,
    ),
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      error: AppColors.error,
      onPrimary: AppColors.textLight,
      onSurface: AppColors.text,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: AppColors.text, fontSize: 16),
      bodyLarge: TextStyle(color: AppColors.text, fontSize: 18),
      labelLarge:
          TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500),
      titleLarge: TextStyle(
          color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 20),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10.0))),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textLight,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ),
  );

  static final ThemeData dark = ThemeData(
    brightness: Brightness.dark,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.backgroundDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surfaceDark,
      iconTheme: IconThemeData(color: AppColors.primary),
      titleTextStyle: TextStyle(
        color: AppColors.primary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      elevation: 1.8,
    ),
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surfaceDark,
      error: AppColors.error,
      onPrimary: AppColors.textLight,
      onSurface: AppColors.textLight,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: AppColors.textLight, fontSize: 16),
      bodyLarge: TextStyle(color: AppColors.textLight, fontSize: 18),
      labelLarge:
          TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500),
      titleLarge: TextStyle(
          color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 20),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceDark,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10.0))),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textLight,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ),
  );
}
