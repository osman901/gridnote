import 'dart:math';
import 'package:flutter/material.dart';

class ArrowLoader extends StatefulWidget {
  const ArrowLoader({super.key, this.size = 140});
  final double size;

  @override
  State<ArrowLoader> createState() => _ArrowLoaderState();
}

class _ArrowLoaderState extends State<ArrowLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final angle = _c.value * 2 * pi;

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      // ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ Ãƒâ€šÃ‚Â cambio: withValues en lugar de withOpacity
                      Colors.greenAccent.withValues(alpha: 0.22),
                      Colors.transparent,
                    ],
                    stops: const [0.55, 1],
                  ),
                ),
              ),
              CustomPaint(
                size: Size.square(widget.size),
                painter: _RingPainter(progress: _c.value),
              ),
              Transform.rotate(
                angle: sin(angle) * 0.25,
                child: ShaderMask(
                  shaderCallback: (r) => SweepGradient(
                    startAngle: 0,
                    endAngle: 2 * pi,
                    colors: const [
                      Color(0xFF00E676),
                      Color(0xFF00C853),
                      Color(0xFF1DE9B6),
                      Color(0xFF00E676),
                    ],
                    stops: const [0.0, 0.4, 0.8, 1.0],
                    transform: GradientRotation(angle),
                  ).createShader(r),
                  blendMode: BlendMode.srcIn,
                  child:
                      Icon(Icons.play_arrow_rounded, size: widget.size * 0.78),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas c, Size s) {
    final sw = s.width * 0.065;
    final rect = Rect.fromLTWH(0, 0, s.width, s.height);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = sw
      ..shader = SweepGradient(
        colors: const [Color(0xFF00E676), Colors.transparent],
        stops: const [0.55, 1],
        transform: GradientRotation(progress * 2 * pi),
      ).createShader(rect);

    final r = s.width / 2 - sw / 2;
    c.drawArc(
      Rect.fromCircle(center: Offset(s.width / 2, s.height / 2), radius: r),
      0,
      2 * pi,
      false,
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}
