// lib/core/gn_shader_warmup.dart
import 'package:flutter/widgets.dart';

/// Calienta shaders típicos (blur, degradados, texto) antes del primer frame.
class GridnoteShaderWarmUp extends ShaderWarmUp {
  GridnoteShaderWarmUp(); // <- NO const

  @override
  Future<void> warmUpOnCanvas(Canvas canvas) async {
    final p = Paint();
    final r = RRect.fromLTRBR(10, 10, 310, 90, const Radius.circular(18));

    // Blur de fondo
    p
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRRect(r, p);

    // Degradado
    p
      ..maskFilter = null
      ..shader = const LinearGradient(
        colors: [Color(0xFF0E1D0E), Color(0xFF1D3A1D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(const Rect.fromLTWH(10, 10, 300, 80));
    canvas.drawRRect(r, p);

    // Texto
    final tp = TextPainter(
      text: const TextSpan(
        text: 'Gridnote',
        style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 18, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, const Offset(24, 36));
  }
}

/// Llamar ANTES de `runApp()` si no usás GNPerf.bootstrap().
Future<void> warmUpEngine() async {
  WidgetsFlutterBinding.ensureInitialized();
  // En 3.32.x el setter es ESTÁTICO; instancia SIN const:
  PaintingBinding.shaderWarmUp = GridnoteShaderWarmUp();
}
