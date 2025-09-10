// lib/services/location_fix_coordinator.dart
// Evita (0,0) en guardados rápidos: serializa lecturas, cachea el último fix
// válido (LKGF), reintenta corto y bloquea escrituras inválidas.
// Requiere: location_service.dart + geo_utils.dart

import 'dart:async';
import '../utils/geo_utils.dart';
import 'location_service.dart';

class LocationFixCoordinator {
  LocationFixCoordinator._();
  static final LocationFixCoordinator instance = LocationFixCoordinator._();

  LocationFix? _lastGood;
  Completer<LocationFix>? _inflight;

  /// Devuelve un fix válido:
  /// - Reusa el último bueno si es reciente y preciso.
  /// - Si hay una lectura en curso, la comparte.
  /// - Reintenta [retries] veces si la lectura falla.
  Future<LocationFix> getFix({
    Duration reuseFor = const Duration(seconds: 10),
    double maxReuseAccuracy = 35.0,
    int retries = 1,
    CancelToken? cancelToken, // opcional: cancelación cooperativa
  }) async {
    // 1) Reuso del último fix bueno
    final lg = _lastGood;
    if (lg != null) {
      final age = DateTime.now().difference(lg.timestamp);
      final acc = lg.accuracyMeters ?? 999.0;
      if (age <= reuseFor && acc <= maxReuseAccuracy && _isValid(lg)) {
        return lg;
      }
    }

    // 2) Compartir lectura en curso
    final existing = _inflight;
    if (existing != null) return existing.future;

    // 3) Nueva lectura (serializada)
    final c = Completer<LocationFix>();
    _inflight = c;
    try {
      final r = await _readOnce(cancelToken: cancelToken);
      _lastGood = r;
      c.complete(r);
    } catch (e) {
      // Reintento corto con backoff
      for (var i = 0; i < retries; i++) {
        await Future<void>.delayed(Duration(milliseconds: 250 * (i + 1)));
        try {
          final r = await _readOnce(cancelToken: cancelToken);
          _lastGood = r;
          c.complete(r);
          break;
        } catch (_) {
          if (i == retries - 1) {
            if (_lastGood != null) {
              c.complete(_lastGood!); // último bueno como fallback
            } else {
              c.completeError(e);
            }
          }
        }
      }
    } finally {
      _inflight = null;
    }
    return c.future;
  }

  /// Invalida manualmente el caché (por ejemplo, si el usuario se movió mucho).
  void invalidate() {
    _lastGood = null;
  }

  // ---------- helpers ----------
  Future<LocationFix> _readOnce({CancelToken? cancelToken}) async {
    // Como no existe getUltraFix en LocationService, usamos getPreciseFix.
    // Aproximamos un “overall timeout” con N muestras * perSampleTimeout.
    const samples = 10;
    const perSampleTimeout = Duration(seconds: 2);
    final fix = await LocationService.instance.getPreciseFix(
      samples: samples,
      perSampleTimeout: perSampleTimeout,
      keepBestFraction: 0.6,
      cancelToken: cancelToken,
      // desiredAccuracy / tryFullAccuracyIOS se pueden ajustar si hiciera falta
    );
    if (!_isValid(fix)) {
      throw const LocationException('Fix inválido');
    }
    return fix;
  }

  bool _isValid(LocationFix? f) {
    if (f == null) return false;
    return GeoUtils.isValid(f.latitude, f.longitude);
  }
}
