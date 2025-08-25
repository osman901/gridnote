import 'package:flutter/material.dart';

class GridnoteTheme {
  const GridnoteTheme({
    required this.scaffold,
    required this.surface,
    required this.text,
    required this.textFaint,
    required this.accent,
    required this.divider,
  });

  final Color scaffold;
  final Color surface;
  final Color text;
  final Color textFaint;
  final Color accent;
  final Color divider;

  factory GridnoteTheme.light() => const GridnoteTheme(
    scaffold: Color(0xFFF7F7F7),
    surface: Color(0xFFFFFFFF),
    text: Color(0xFF1F2428),
    textFaint: Color(0x991F2428),
    accent: Color(0xFF2962FF),
    divider: Color(0x1F000000),
  );

  /// DARK + GREEN (fondo negro más intenso, texto claro, rejas verdes)
  factory GridnoteTheme.dark() => const GridnoteTheme(
    scaffold: Color(0xFF070908), // más negro
    surface:  Color(0xFF0B0E0C), // panel
    text:     Color(0xFFECEFEA),
    textFaint:Color(0x99ECEFEA),
    accent:   Color(0xFF00E676), // verde principal
    divider:  Color(0x3300E676), // rejas verdes sutiles
  );

  GridnoteTheme copyWith({
    Color? scaffold,
    Color? surface,
    Color? text,
    Color? textFaint,
    Color? accent,
    Color? divider,
  }) =>
      GridnoteTheme(
        scaffold: scaffold ?? this.scaffold,
        surface: surface ?? this.surface,
        text: text ?? this.text,
        textFaint: textFaint ?? this.textFaint,
        accent: accent ?? this.accent,
        divider: divider ?? this.divider,
      );
}

class GridnoteThemeController extends ChangeNotifier {
  GridnoteThemeController({GridnoteTheme? initial})
      : _theme = initial ?? GridnoteTheme.dark(); // por defecto dark+green
  GridnoteTheme _theme;
  GridnoteTheme get theme => _theme;

  void setTheme(GridnoteTheme t) { _theme = t; notifyListeners(); }
  void toggleDark() {
    final isDark = _theme.scaffold.computeLuminance() < 0.5;
    _theme = isDark ? GridnoteTheme.light() : GridnoteTheme.dark();
    notifyListeners();
  }
}

/// Paleta específica para la tabla
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

  final Color gridLine;   // rejas
  final Color cellBg;
  final Color altCellBg;
  final Color headerBg;
  final Color headerText;
  final Color selection;  // foco/selección
  final String fontFamily;

  factory GridnoteTableStyle.from(GridnoteTheme t) => GridnoteTableStyle(
    gridLine: t.divider,
    cellBg: t.surface,
    altCellBg: t.surface.withValues(alpha: 0.94),
    headerBg: const Color(0xFF102015), // verde muy oscuro
    headerText: t.text,
    selection: t.accent,
    fontFamily: 'Arimo',
  );
}
