import 'package:flutter/material.dart';

class FadeScaleRoute extends PageRouteBuilder {
  FadeScaleRoute({required Widget child})
      : super(
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (_, __, ___) => child,
    transitionsBuilder: (_, anim, __, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: .98, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}
