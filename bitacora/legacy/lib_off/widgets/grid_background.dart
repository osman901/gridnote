import 'package:flutter/material.dart';

/// Dibuja una cuadrÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­cula gris muy tenue detrÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡s de cualquier widget hijo.
class GridBackground extends StatelessWidget {
  const GridBackground({super.key, required this.child, this.cellSize = 56});

  final Widget child;
  final double cellSize; // puedes hacerla mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡s fina o mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡s gruesa

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
      ..color = Colors.white.withValues(alpha: .07)
      ..strokeWidth = .75;

    // LÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­neas horizontales
    for (double y = 0; y < size.height; y += cellSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // LÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­neas verticales
    for (double x = 0; x < size.width; x += cellSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
