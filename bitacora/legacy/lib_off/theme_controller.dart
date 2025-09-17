// lib/theme/theme_controller.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ThemeController {
  final ThemeData theme;
  ThemeController(this.theme);
}

// Atajo para usar algo por defecto si no se provee otro ThemeController.
// Idealmente, en tus pantallas usá Theme.of(context).
final themeControllerProvider = Provider<ThemeController>(
      (ref) => ThemeController(ThemeData.light()),
);

// Helper: permite `theme.surface`
extension ThemeSurface on ThemeData {
  Color get surface => colorScheme.surface;
}
