// lib/theme/gridnote_tokens.dart
//
// ThemeExtension simple para tematizar el picker.

import 'package:flutter/material.dart';

@immutable
class GridnoteTokens extends ThemeExtension<GridnoteTokens> {
  final Color accent;
  final Color surface;
  final Color divider;
  final Color onSurface;

  const GridnoteTokens({
    required this.accent,
    required this.surface,
    required this.divider,
    required this.onSurface,
  });

  @override
  GridnoteTokens copyWith({
    Color? accent,
    Color? surface,
    Color? divider,
    Color? onSurface,
  }) {
    return GridnoteTokens(
      accent: accent ?? this.accent,
      surface: surface ?? this.surface,
      divider: divider ?? this.divider,
      onSurface: onSurface ?? this.onSurface,
    );
  }

  @override
  GridnoteTokens lerp(ThemeExtension<GridnoteTokens>? other, double t) {
    if (other is! GridnoteTokens) return this;
    return GridnoteTokens(
      accent: Color.lerp(accent, other.accent, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
    );
  }
}
