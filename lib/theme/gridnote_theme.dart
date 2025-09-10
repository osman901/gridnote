import 'package:flutter/material.dart';

class GridnoteTheme {
  const GridnoteTheme({
    required this.scaffold,
    required this.surface,
    required this.text,
    required this.textFaint,
    required this.accent,
    required this.divider,
    required this.selection,
  });

  final Color scaffold;
  final Color surface;
  final Color text;
  final Color textFaint;
  final Color accent;     // acento (botones, foco)
  final Color divider;    // líneas sutiles
  final Color selection;  // resalte/selección

  // Claro
  factory GridnoteTheme.light() => GridnoteTheme(
    scaffold: const Color(0xFFF6F6F6),
    surface: const Color(0xFFFFFFFF),
    text: const Color(0xFF141414),
    textFaint: const Color(0x99141414),
    accent: const Color(0xFF000000),
    divider: const Color(0x19000000),
    selection: const Color(0xFF000000).withOpacity(.18),
  );

  // Oscuro
  factory GridnoteTheme.dark() => GridnoteTheme(
    scaffold: const Color(0xFF0C0C0C),
    surface: const Color(0xFF141414),
    text: const Color(0xFFF0F0F0),
    textFaint: const Color(0x99F0F0F0),
    accent: const Color(0xFFFFFFFF),
    divider: const Color(0x22FFFFFF),
    selection: const Color(0xFFFFFFFF).withOpacity(.35),
  );

  GridnoteTheme copyWith({
    Color? scaffold,
    Color? surface,
    Color? text,
    Color? textFaint,
    Color? accent,
    Color? divider,
    Color? selection,
  }) =>
      GridnoteTheme(
        scaffold: scaffold ?? this.scaffold,
        surface: surface ?? this.surface,
        text: text ?? this.text,
        textFaint: textFaint ?? this.textFaint,
        accent: accent ?? this.accent,
        divider: divider ?? this.divider,
        selection: selection ?? this.selection,
      );
}

class GridnoteThemeController extends ChangeNotifier {
  GridnoteThemeController({GridnoteTheme? initial})
      : _theme = initial ?? GridnoteTheme.dark();
  GridnoteTheme _theme;
  GridnoteTheme get theme => _theme;

  void setTheme(GridnoteTheme t) {
    _theme = t;
    notifyListeners();
  }

  void toggleDark() {
    final isDark = _theme.scaffold.computeLuminance() < 0.5;
    _theme = isDark ? GridnoteTheme.light() : GridnoteTheme.dark();
    notifyListeners();
  }
}

/// Estilo para tablas
class GridnoteTableStyle {
  const GridnoteTableStyle({
    required this.gridLine,
    required this.cellBg,
    required this.altCellBg,
    required this.headerBg,
    required this.headerText,
    required this.selection,
    required this.fontFamily,
  });

  final Color gridLine;
  final Color cellBg;
  final Color altCellBg;
  final Color headerBg;
  final Color headerText;
  final Color selection;
  final String fontFamily;

  factory GridnoteTableStyle.from(GridnoteTheme t) {
    final isDark = t.scaffold.computeLuminance() < 0.5;
    return GridnoteTableStyle(
      gridLine: t.divider,
      cellBg: t.surface,
      altCellBg: isDark ? const Color(0xFF101010) : const Color(0xFFF9F9F9),
      headerBg: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFEFEFEF),
      headerText: t.text,
      selection: t.selection,
      fontFamily: 'Arimo',
    );
  }
}
