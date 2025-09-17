// lib/core/gn_perf.dart
import 'package:flutter/widgets.dart';
import 'package:flutter/gestures.dart' show GestureBinding;
import 'gn_shader_warmup.dart';

class GNPerf {
  static Future<void> bootstrap({int imageCacheMb = 160}) async {
    WidgetsFlutterBinding.ensureInitialized();

    // sin const (tu constructor no es const)
    PaintingBinding.shaderWarmUp = GridnoteShaderWarmUp();

    final cache = PaintingBinding.instance.imageCache;
    cache.maximumSizeBytes = imageCacheMb * 1024 * 1024;
    cache.maximumSize = (cache.maximumSize * 2).clamp(1000, 5000);

    GestureBinding.instance.resamplingEnabled = true;
  }

  static void reportError(Object error, StackTrace stack) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stack),
    );
  }
}
