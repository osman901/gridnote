// lib/core/gn_scroll_behavior.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// ScrollBehavior con rebote estilo iOS opcional en todas las plataformas.
class GNScrollBehavior extends ScrollBehavior {
  const GNScrollBehavior({this.alwaysBounce = false});

  /// Si true, fuerza BouncingScrollPhysics en todas las plataformas.
  final bool alwaysBounce;

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    // Evita el glow azul en Android: no dibuja ningún indicador extra.
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // En iOS siempre hay rebote; en otras plataformas depende de alwaysBounce.
    final physics = alwaysBounce || Theme.of(context).platform == TargetPlatform.iOS
        ? const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())
        : const ClampingScrollPhysics();
    return physics;
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
