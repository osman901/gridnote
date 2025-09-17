// lib/theme/gridnote_theme.dart
import 'package:flutter/material.dart';

/// Tema mínimo para compilar sin dependencias externas.
class GridnoteTheme {
  final Color scaffold;
  final Color divider;
  final Color accent;

  const GridnoteTheme({
    required this.scaffold,
    required this.divider,
    required this.accent,
  });

  factory GridnoteTheme.dark() => GridnoteTheme(
    scaffold: const Color(0xFF0E0E10),
    divider: Colors.white12,
    accent: const Color(0xFF64D2FF),
  );

  factory GridnoteTheme.light() => GridnoteTheme(
    scaffold: const Color(0xFFF7F7F8),
    divider: Colors.black12,
    accent: const Color(0xFF007AFF),
  );
}

/// Controlador súper simple (singleton) para elegir claro/oscuro.
class GridnoteThemeController extends ChangeNotifier {
  static final GridnoteThemeController _i = GridnoteThemeController._();
  factory GridnoteThemeController() => _i;
  GridnoteThemeController._();

  bool _dark = true;
  bool get isDark => _dark;

  GridnoteTheme get theme => _dark ? GridnoteTheme.dark() : GridnoteTheme.light();

  void setDark(bool v) {
    if (_dark == v) return;
    _dark = v;
    notifyListeners();
  }
}
