import 'package:flutter/material.dart';

/// Dibuja una cuadrícula gris muy tenue detrás de cualquier widget hijo.
class GridBackground extends StatelessWidget {
  const GridBackground({super.key, required this.child, this.cellSize = 56});

  final Widget child;
  final double cellSize; // puedes hacerla más fina o más gruesa

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GridPainter(cellSize),
      child: child,
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.cellSize);

  final double cellSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(.07)
      ..strokeWidth = .75;

    // Líneas horizontales
    for (double y = 0; y < size.height; y += cellSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Líneas verticales
    for (double x = 0; x < size.width; x += cellSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}