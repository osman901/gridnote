// lib/widgets/busy_overlay.dart
import 'package:flutter/material.dart';
import 'arrow_loader.dart';

class BusyOverlay extends StatelessWidget {
  const BusyOverlay({super.key, required this.busy, required this.child});
  final bool busy;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        IgnorePointer(
          ignoring: !busy,
          child: AnimatedOpacity(
            opacity: busy ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              color: Colors.black.withOpacity(0.25),
              alignment: Alignment.center,
              child: const ArrowLoader(size: 96),
            ),
          ),
        ),
      ],
    );
  }
}
