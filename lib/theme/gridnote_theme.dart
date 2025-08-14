import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum GridnotePalette { lightCeleste, darkNegroGris }

class GridnoteTheme {
  final Color scaffold;
  final Color surface;
  final Color surfaceAlt;
  final Color text;
  final Color textFaint;
  final Color divider;
  final Color accent;

  const GridnoteTheme({
    required this.scaffold,
    required this.surface,
    required this.surfaceAlt,
    required this.text,
    required this.textFaint,
    required this.divider,
    required this.accent,
  });

  static GridnoteTheme of(GridnotePalette p) {
    switch (p) {
      case GridnotePalette.lightCeleste:
        return const GridnoteTheme(
          scaffold: Colors.white,
          surface: Color(0xFFF6F9FF),
          surfaceAlt: Color(0xFFEEF5FF),
          text: Color(0xFF0F172A),
          textFaint: Color(0xFF475569),
          divider: Color(0xFFE2E8F0),
          accent: Color(0xFF0EA5E9),
        );
      case GridnotePalette.darkNegroGris:
        return const GridnoteTheme(
          scaffold: Color(0xFF0B0B0C),
          surface: Color(0xFF121316),
          surfaceAlt: Color(0xFF1A1C20),
          text: Colors.white,
          textFaint: Color(0xFFCBD5E1),
          divider: Color(0xFF2A2D32),
          accent: Colors.white,
        );
    }
  }

  ThemeData toThemeData() {
    final isDark = scaffold.computeLuminance() < 0.5;
    final base = isDark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);

    // Evitamos 'background' y 'onBackground' (deprecados) usando copyWith.
    final scheme = (isDark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
      primary: accent,
      onPrimary: isDark ? Colors.black : Colors.white,
      secondary: accent,
      onSecondary: isDark ? Colors.black : Colors.white,
      error: isDark ? Colors.red.shade200 : Colors.red.shade700,
      onError: isDark ? Colors.black : Colors.white,
      surface: surface,
      onSurface: text,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      dividerColor: divider,
      textTheme: base.textTheme.apply(bodyColor: text, displayColor: text),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: text,
        elevation: 0.5,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: divider),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: divider),
        ),
      ),
    );
  }
}

class GridnoteThemeController extends ChangeNotifier {
  static const _kKey = 'gridnote_palette';
  GridnotePalette _palette = GridnotePalette.lightCeleste;
  GridnotePalette get palette => _palette;
  GridnoteTheme get theme => GridnoteTheme.of(_palette);

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final idx = sp.getInt(_kKey);
    if (idx != null && idx >= 0 && idx < GridnotePalette.values.length) {
      _palette = GridnotePalette.values[idx];
      notifyListeners();
    }
  }

  Future<void> set(GridnotePalette p) async {
    _palette = p;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kKey, p.index);
  }
}

class GridnoteTableStyle {
  final Color headerBg;
  final Color headerText;
  final Color cellBg;
  final Color cellBgAlt;
  final Color cellText;
  final Color gridLine;

  GridnoteTableStyle({
    required this.headerBg,
    required this.headerText,
    required this.cellBg,
    required this.cellBgAlt,
    required this.cellText,
    required this.gridLine,
  });

  factory GridnoteTableStyle.from(GridnoteTheme t) {
    final isDark = t.scaffold.computeLuminance() < 0.5;
    return GridnoteTableStyle(
      headerBg: isDark ? t.surfaceAlt : t.surface,
      headerText: t.text,
      cellBg: t.surface,
      cellBgAlt: t.surfaceAlt,
      cellText: t.text,
      gridLine: t.divider,
    );
  }
}
