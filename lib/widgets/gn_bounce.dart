import 'package:flutter/material.dart';
import '../main.dart'; // GNScrollBehavior

/// Envuelve cualquier scroll (ListView/PlutoGrid/CustomScrollView) para forzar rebote iOS.
class GNBounce extends StatelessWidget {
  const GNBounce({
    super.key,
    required this.child,
    this.showScrollbar = true,
  });

  final Widget child;
  final bool showScrollbar;

  @override
  Widget build(BuildContext context) {
    final content = ScrollConfiguration(
      behavior: const GNScrollBehavior(alwaysBounce: true),
      child: child,
    );

    return showScrollbar
        ? Scrollbar(
      thickness: 3,
      radius: const Radius.circular(16),
      interactive: true,
      child: content,
    )
        : content;
  }
}
