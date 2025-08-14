// lib/services/offline_geo.dart
import 'dart:async';
import 'package:geolocator/geolocator.dart';

class OfflineGeo {
  /// Llama esto al inicio para asegurar permisos/servicio.
  static Future<bool> ensureReady() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always || perm == LocationPermission.whileInUse;
  }

  /// Coordenadas offline con buena UX:
  /// 1) devuelve rápido el lastKnown si existe
  /// 2) intenta un fix de GPS con alta precisión y timeout
  static Future<Position?> current({Duration timeout = const Duration(seconds: 25)}) async {
    // 1) rápido si hay cache
    final last = await Geolocator.getLastKnownPosition();
    // 2) pedir fix preciso (GPS). En ^10.x se usa desiredAccuracy
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(timeout);
      // Si había last y era “reciente”, podés decidir cuál preferir
      return pos;
    } on TimeoutException {
      // si no logró fix en tiempo, devolvé lo que tengas
      return last;
    } catch (_) {
      return last;
    }
  }

  /// Stream para “calentar” y recibir updates (offline)
  static Stream<Position> watch({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilterMeters = 5,
  }) {
    return Geolocator.getPositionStream(
      desiredAccuracy: accuracy,
      distanceFilter: distanceFilterMeters,
    );
  }
}
