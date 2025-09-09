import 'dart:ui';
import 'dart:io';  // import para detectar plataforma
import 'package:flutter/material.dart';

class Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  const Glass({super.key, required this.child, this.padding = const EdgeInsets.all(12), this.radius = 18});

  @override
  Widget build(BuildContext context) {
    // Ajustar desenfoque segÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºn potencia del dispositivo
    final bool isHighEnd = Platform.numberOfProcessors >= 8 || (Platform.isIOS && Platform.numberOfProcessors >= 6);
    final double appliedRadius = isHighEnd ? radius : (radius * 0.6);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: appliedRadius, sigmaY: appliedRadius),
        child: Container(padding: padding, child: child),
      ),
    );
  }
}
