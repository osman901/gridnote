import 'package:flutter/material.dart';

/// Paleta/tema usado por HomeScreen y widgets.
class GridnoteTheme {
  final Color scaffold;
  final Color surface;
  final Color text;
  final Color textFaint;
  final Color divider;
  final Color accent;

  const GridnoteTheme({
    required this.scaffold,
    required this.surface,
    required this.text,
    required this.textFaint,
    required this.divider,
    required this.accent,
  });

  factory GridnoteTheme.light() => const GridnoteTheme(
    scaffold: Color(0xFFF7F7F7),
    surface: Colors.white,
    text: Color(0xFF1B1B1B),
    textFaint: Color(0x991B1B1B),
    divider: Color(0x14000000),
    accent: Color(0xFF2B8AFF),
  );

  factory GridnoteTheme.dark() => const GridnoteTheme(
    scaffold: Color(0xFF101114),
    surface: Color(0xFF16181C),
    text: Color(0xFFECECEC),
    textFaint: Color(0x99ECECEC),
    divider: Color(0x22FFFFFF),
    accent: Color(0xFF70B0FF),
  );
}

/// Controlador de tema compatible con Riverpod ChangeNotifierProvider.
class GridnoteThemeController extends ChangeNotifier {
  bool _isDark = true;

  GridnoteTheme get theme =>
      _isDark ? GridnoteTheme.dark() : GridnoteTheme.light();

  void toggleDark() {
    _isDark = !_isDark;
    notifyListeners();
  }
}

// ***IMPORTANTE***
// Este archivo NO debe declarar un provider.
// Usá el provider definido en lib/providers.dart:
//   final themeControllerProvider = ChangeNotifierProvider<GridnoteThemeController>((ref) => GridnoteThemeController());
