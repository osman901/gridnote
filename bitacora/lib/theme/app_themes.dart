// lib/theme/app_themes.dart
import 'package:flutter/material.dart';
import 'app_colors_extension.dart';

class AppThemes {
  // Paleta oscura
  static const AppColors _dark = AppColors(
    scaffold: Color(0xFF121212),
    surface:  Color(0xFF1E1E1E),
    text:     Colors.white,
    textFaint: Colors.white70,
    accent:   Color(0xFF80D8FF),
  );

  // Paleta clara (opcional)
  static const AppColors _light = AppColors(
    scaffold: Color(0xFFF7F7F7),
    surface:  Colors.white,
    text:     Color(0xFF1C1C1C),
    textFaint: Colors.black54,
    accent:   Color(0xFF007AFF),
  );

  static ThemeData dark() {
    final scheme = ColorScheme.dark( // <- sin const
      primary: _dark.accent,
      surface: _dark.surface,
      background: _dark.scaffold,
    );
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: _dark.scaffold,
      appBarTheme: AppBarTheme(
        backgroundColor: _dark.surface,
        foregroundColor: _dark.text,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _dark.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _dark.accent,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      extensions: const <ThemeExtension<dynamic>>[_dark],
    );
  }

  static ThemeData light() {
    final scheme = ColorScheme.light( // <- sin const
      primary: _light.accent,
      surface: _light.surface,
      background: _light.scaffold,
    );
    return ThemeData(
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: _light.scaffold,
      appBarTheme: AppBarTheme(
        backgroundColor: _light.surface,
        foregroundColor: _light.text,
        elevation: 0.5,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _light.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _light.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      extensions: const <ThemeExtension<dynamic>>[_light],
    );
  }
}
