import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTheme { system, light, dark, gray }

class ThemeManager extends ChangeNotifier {
  static const _kThemeKey = 'app_theme';
  static const _kFontScaleKey = 'font_scale';

  AppTheme _theme = AppTheme.system;
  double _fontScale = 1.0;

  AppTheme get theme => _theme;
  double get fontScale => _fontScale;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _theme = AppTheme.values[prefs.getInt(_kThemeKey) ?? 0];
    _fontScale = prefs.getDouble(_kFontScaleKey) ?? 1.0;
    notifyListeners();
  }

  Future<void> setTheme(AppTheme t) async {
    _theme = t;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kThemeKey, t.index);
    notifyListeners();
  }

  Future<void> setFontScale(double s) async {
    _fontScale = s.clamp(0.8, 1.4);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kFontScaleKey, _fontScale);
    notifyListeners();
  }

  ThemeData resolveTheme(Brightness platformBrightness) {
    switch (_theme) {
      case AppTheme.light:
        return _baseLight();
      case AppTheme.dark:
        return _baseDark();
      case AppTheme.gray:
        return _baseGray(platformBrightness);
      case AppTheme.system:
      default:
        return platformBrightness == Brightness.dark ? _baseDark() : _baseLight();
    }
  }

  // ====== Paletas ======
  ThemeData _baseLight() {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0), brightness: Brightness.light);
    return _applyCommon(ThemeData(colorScheme: scheme, useMaterial3: true));
  }

  ThemeData _baseDark() {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF00BCD4), brightness: Brightness.dark);
    return _applyCommon(ThemeData(colorScheme: scheme, useMaterial3: true));
  }

  /// Gris/Negro minimalista (lo que pediste)
  ThemeData _baseGray(Brightness platformBrightness) {
    final scheme = ColorScheme(
      brightness: platformBrightness,
      primary: const Color(0xFF2B2B2B),
      onPrimary: Colors.white,
      secondary: const Color(0xFF616161),
      onSecondary: Colors.white,
      error: const Color(0xFFEF5350),
      onError: Colors.white,
      background: platformBrightness == Brightness.dark ? const Color(0xFF111111) : const Color(0xFFF4F4F4),
      onBackground: platformBrightness == Brightness.dark ? Colors.white : const Color(0xFF1E1E1E),
      surface: platformBrightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white,
      onSurface: platformBrightness == Brightness.dark ? Colors.white : const Color(0xFF1E1E1E),
      shadow: Colors.black.withOpacity(.3),
      outline: const Color(0xFF9E9E9E),
      outlineVariant: const Color(0xFFE0E0E0),
      surfaceTint: const Color(0xFF2B2B2B),
      tertiary: const Color(0xFF424242),
      onTertiary: Colors.white,
      primaryContainer: const Color(0xFF3A3A3A),
      onPrimaryContainer: Colors.white,
      secondaryContainer: const Color(0xFFEEEEEE),
      onSecondaryContainer: const Color(0xFF1E1E1E),
      surfaceVariant: platformBrightness == Brightness.dark ? const Color(0xFF202020) : const Color(0xFFF2F2F2),
      inverseSurface: platformBrightness == Brightness.dark ? Colors.white : Colors.black,
      inversePrimary: const Color(0xFFBDBDBD),
      scrim: Colors.black87,
    );
    return _applyCommon(ThemeData(colorScheme: scheme, useMaterial3: true));
  }

  ThemeData _applyCommon(ThemeData base) {
    final txt = base.textTheme.apply(fontSizeFactor: _fontScale);
    return base.copyWith(
      textTheme: txt,
      appBarTheme: base.appBarTheme.copyWith(
        elevation: 1,
        centerTitle: false,
      ),
      snackBarTheme: base.snackBarTheme.copyWith(behavior: SnackBarBehavior.floating),
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      dividerColor: base.colorScheme.outline.withOpacity(.3),
    );
  }
}