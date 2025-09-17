// lib/perf/perf_boost.dart
// Uso en main():
//   void main() async {
//     WidgetsFlutterBinding.ensureInitialized();
//     await PerfBoost.install();
//     runApp(const MyApp());
//   }

import 'dart:async';
import 'dart:isolate';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PerfBoost {
  static Future<void> install({
    ImageCacheSizes caches = const ImageCacheSizes(),
    bool warmUpShaders = true,
    int warmUpPasses = 2,
    int warmUpDelayMs = 8,
  }) async {
    // 1) CachÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© de imÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡genes.
    final cache = PaintingBinding.instance.imageCache;
    cache.maximumSize = caches.maxEntries;
    cache.maximumSizeBytes = caches.maxBytes;

    // 2) Responder a presiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n de memoria (firma Object?).
    SystemChannels.system.setMessageHandler((Object? message) async {
      if (message == 'memoryPressure') {
        cache.clear();
        cache.clearLiveImages();
      }
      return null;
    });

    // 3) Liberar cachÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© al ir a background.
    WidgetsBinding.instance.addObserver(_LifecycleEvictor(cache));

    // 4) Warmup de shaders (setter estÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡tico).
    if (warmUpShaders) {
      PaintingBinding.shaderWarmUp = const _LeanShaderWarmUp();
    }

    // 5) Tibiar primeros frames.
    for (var i = 0; i < warmUpPasses; i++) {
      await Future<void>.delayed(Duration(milliseconds: warmUpDelayMs));
    }

    // 6) Silenciar prints en release (firma correcta).
    if (kReleaseMode) {
      debugPrint = (String? message, {int? wrapWidth}) {};
    }
  }

  static Future<T> background<T>(FutureOr<T> Function() job) => Isolate.run(job);

  static Debouncer debouncer([Duration delay = const Duration(milliseconds: 250)]) =>
      Debouncer(delay);
}

class ImageCacheSizes {
  final int maxEntries;
  final int maxBytes;
  const ImageCacheSizes({
    this.maxEntries = 300,
    this.maxBytes = 120 * 1024 * 1024,
  });
}

class Debouncer {
  Debouncer(this.delay);
  final Duration delay;
  Timer? _t;
  void call(VoidCallback action) {
    _t?.cancel();
    _t = Timer(delay, action);
  }
  void dispose() => _t?.cancel();
}

class _LifecycleEvictor extends WidgetsBindingObserver {
  _LifecycleEvictor(this._cache);
  final ImageCache _cache;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _cache.clear();
    }
  }
}

class _LeanShaderWarmUp extends ShaderWarmUp {
  const _LeanShaderWarmUp();

  @override
  Future<void> warmUpOnCanvas(ui.Canvas canvas) async {
    final p = Paint()..isAntiAlias = true;

    // Gradiente
    final rect = const Offset(0, 0) & const Size(256, 256);
    p.shader = ui.Gradient.linear(
      const Offset(0, 0),
      const Offset(256, 256),
      const [Color(0xFF000000), Color(0xFFFFFFFF)],
    );
    canvas.drawRect(rect, p);

    // Texto
    final pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(fontSize: 16, fontWeight: FontWeight.w400),
    )
      ..pushStyle(ui.TextStyle(color: const Color(0xFF000000)))
      ..addText('shader warmup');
    final paragraph = pb.build()..layout(const ui.ParagraphConstraints(width: 256));
    canvas.drawParagraph(paragraph, const Offset(8, 8));

    // saveLayer / blur
    final blurPaint = Paint()
      ..imageFilter = ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4)
      ..color = const Color(0x22000000);
    canvas.saveLayer(rect, blurPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(12), const Radius.circular(16)),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    canvas.restore();

    // CÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­rculos AA
    final dot = Paint()..color = const Color(0xFF2196F3)..isAntiAlias = true;
    for (var i = 0; i < 10; i++) {
      canvas.drawCircle(Offset(12.0 * i, 240), 6, dot);
    }
  }
}

