import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.scaffold,
    required this.surface,
    required this.text,
    required this.textFaint,
    required this.accent,
  });

  final Color scaffold;
  final Color surface;
  final Color text;
  final Color textFaint;
  final Color accent;

  @override
  AppColors copyWith({
    Color? scaffold,
    Color? surface,
    Color? text,
    Color? textFaint,
    Color? accent,
  }) {
    return AppColors(
      scaffold: scaffold ?? this.scaffold,
      surface: surface ?? this.surface,
      text: text ?? this.text,
      textFaint: textFaint ?? this.textFaint,
      accent: accent ?? this.accent,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      scaffold: Color.lerp(scaffold, other.scaffold, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      text: Color.lerp(text, other.text, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
    );
  }
}
