// lib/core/gn_scroll_behavior.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Scroll universal con soporte mouse/trackpad y rebote opcional.
class GNScrollBehavior extends MaterialScrollBehavior {
  const GNScrollBehavior({this.alwaysBounce = false});
  final bool alwaysBounce;

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
  };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    final base = super.getScrollPhysics(context);
    if (!alwaysBounce) return base;
    // Bouncing tambiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©n en Android/Web cuando se pide.
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())
        .applyTo(base);
  }
}
