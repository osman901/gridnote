import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Motor de auto-tuning: monitorea frames y activa modo "low spec"
/// cuando hay jank sostenido. ÃƒÆ’Ã†â€™Ãƒâ€¦Ã‚Â¡til para desactivar blur/sombras en
/// equipos lentos o momentos de mucha carga.
class PerfBoost extends ChangeNotifier {
  PerfBoost._();
  static final PerfBoost instance = PerfBoost._();

  final ValueNotifier<bool> lowSpec = ValueNotifier<bool>(false);

  // Accesos rÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡pidos
  static bool get isLowSpec => instance.lowSpec.value;
  static void forceLowSpec([bool v = true]) {
    if (instance.lowSpec.value != v) instance.lowSpec.value = v;
  }

  bool _started = false;
  int _window = 120;               // tamaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â±o de ventana (frames)
  double _jankMs = 18.0;           // umbral jank (60 Hz ~16.6ms; usamos 18ms)
  double _enableAt = 0.20;         // % jank para activar lowSpec
  double _disableBelow = 0.05;     // % jank para desactivar lowSpec
  int _total = 0, _janks = 0;

  void start({
    int window = 120,
    double jankThresholdMs = 18.0,
    double jankRatioToEnable = 0.20,
    double jankRatioToDisable = 0.05,
  }) {
    if (_started) return;
    _started = true;
    _window = window;
    _jankMs = jankThresholdMs;
    _enableAt = jankRatioToEnable;
    _disableBelow = jankRatioToDisable;

    SchedulerBinding.instance.addTimingsCallback((List<FrameTiming> timings) {
      for (final t in timings) {
        // Usamos la fase de raster como indicador de ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã¢â‚¬Å“costoÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â.
        final ms = t.rasterDuration.inMicroseconds / 1000.0;
        _total++;
        if (ms > _jankMs) _janks++;

        // Ventana deslizante simple
        if (_total > _window) {
          // Decaimiento: reducimos contadores para mantener ventana aprox.
          _total = (_total * 0.9).round();
          _janks = (_janks * 0.9).round();
        }

        final ratio = _total == 0 ? 0.0 : _janks / _total;
        if (!lowSpec.value && ratio >= _enableAt) {
          lowSpec.value = true;      // bajar efectos
        } else if (lowSpec.value && ratio <= _disableBelow) {
          lowSpec.value = false;     // volver a efectos completos
        }
      }
    });
  }
}
