// lib/widgets/signature_pad.dart
//
// SignaturePad: widget de firma simple con export a PNG.
// Soluciona el error de "RenderRepaintBoundary no es un tipo"
// importando 'package:flutter/rendering.dart' con alias.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' as rendering;

/// Controlador para manipular el pad y exportar imagen.
class SignaturePadController extends ChangeNotifier {
  SignaturePadController({
    this.strokeColor = Colors.white,
    this.strokeWidth = 3.0,
  });

  Color strokeColor;
  double strokeWidth;

  final List<_Stroke> _strokes = <_Stroke>[];
  final List<_Stroke> _redo = <_Stroke>[];

  GlobalKey? _boundaryKey;

  bool get isEmpty => _strokes.isEmpty;

  void clear() {
    _strokes.clear();
    _redo.clear();
    notifyListeners();
  }

  void undo() {
    if (_strokes.isNotEmpty) {
      _redo.add(_strokes.removeLast());
      notifyListeners();
    }
  }

  void redo() {
    if (_redo.isNotEmpty) {
      _strokes.add(_redo.removeLast());
      notifyListeners();
    }
  }

  /// Exporta el contenido como PNG. Devuelve null si el render aún no está listo.
  Future<Uint8List?> toPngBytes({double pixelRatio = 3.0}) async {
    final key = _boundaryKey;
    final ctx = key?.currentContext;
    if (ctx == null) return null;

    final obj = ctx.findRenderObject();
    if (obj is! rendering.RenderRepaintBoundary) return null;

    final image = await obj.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  // ----- Interno (usado por el widget) -----
  void _attach(GlobalKey key) => _boundaryKey = key;
  void _detach() => _boundaryKey = null;

  void _beginStroke(Offset p) {
    _redo.clear();
    _strokes.add(
      _Stroke(color: strokeColor, width: strokeWidth, points: <Offset>[p]),
    );
    notifyListeners();
  }

  void _appendPoint(Offset p) {
    if (_strokes.isEmpty) return;
    _strokes.last.points.add(p);
    notifyListeners();
  }

  List<_Stroke> _snapshot() => List<_Stroke>.unmodifiable(_strokes);
}

/// Widget del área de firma.
class SignaturePad extends StatefulWidget {
  const SignaturePad({
    super.key,
    required this.controller,
    this.backgroundColor,
    this.height = 220,
    this.borderRadius = 12,
    this.decoration,
  });

  final SignaturePadController controller;
  final Color? backgroundColor;
  final double height;
  final double borderRadius;
  final BoxDecoration? decoration;

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  final _repaintKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.controller._attach(_repaintKey);
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant SignaturePad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      oldWidget.controller._detach();
      widget.controller._attach(_repaintKey);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    widget.controller._detach();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final strokes = widget.controller._snapshot();

    final content = RepaintBoundary(
      key: _repaintKey,
      child: CustomPaint(
        painter: _SignaturePainter(
          strokes: strokes,
          background: widget.backgroundColor,
        ),
        child: const SizedBox.expand(),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Container(
        height: widget.height,
        decoration: widget.decoration ??
            BoxDecoration(
              color: widget.backgroundColor ?? const Color(0xFF1C1C1E),
              border: Border.all(color: Colors.white12),
            ),
        child: GestureDetector(
          onPanStart: (d) => widget.controller._beginStroke(d.localPosition),
          onPanUpdate: (d) => widget.controller._appendPoint(d.localPosition),
          child: content,
        ),
      ),
    );
  }
}

class _Stroke {
  _Stroke({
    required this.color,
    required this.width,
    required this.points,
  });

  final Color color;
  final double width;
  final List<Offset> points;
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter({required this.strokes, this.background});

  final List<_Stroke> strokes;
  final Color? background;

  @override
  void paint(Canvas canvas, Size size) {
    // Fondo
    if (background != null) {
      final bg = Paint()..color = background!;
      canvas.drawRect(Offset.zero & size, bg);
    }

    for (final s in strokes) {
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = s.width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true;

      if (s.points.length == 1) {
        // Punto único (toque breve)
        canvas.drawPoints(
          ui.PointMode.points,
          s.points,
          paint..strokeWidth = s.width + 1,
        );
        continue;
      }

      final path = Path()..moveTo(s.points.first.dx, s.points.first.dy);
      for (int i = 1; i < s.points.length; i++) {
        path.lineTo(s.points[i].dx, s.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) {
    return oldDelegate.strokes != strokes || oldDelegate.background != background;
  }
}
