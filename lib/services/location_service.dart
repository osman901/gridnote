// lib/services/location_service.dart
import 'dart:async';
import 'dart:io' show Platform;

import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/geo_utils.dart';

class LocationException implements Exception {
  final String message;
  const LocationException(this.message);
  @override
  String toString() => 'LocationException: $message';
}

class LocationFix {
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final double? altitudeMeters;
  final double? speedMps;
  final double? headingDeg;
  final DateTime timestamp;
  final int usedSamples;
  final int discardedSamples;

  const LocationFix({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.altitudeMeters,
    this.speedMps,
    this.headingDeg,
    required this.timestamp,
    this.usedSamples = 1,
    this.discardedSamples = 0,
  });

  String toGeoUri({String? label}) =>
      GeoUtils.geoUri(latitude, longitude, label: label).toString();

  Uri toMapsUri() => GeoUtils.mapsUri(latitude, longitude);

  Map<String, dynamic> toJson() => {
    'lat': latitude,
    'lng': longitude,
    'accuracy': accuracyMeters,
    'alt': altitudeMeters,
    'speed': speedMps,
    'heading': headingDeg,
    'ts': timestamp.toUtc().toIso8601String(),
    'samples_used': usedSamples,
    'samples_discarded': discardedSamples,
  };
}

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  static const _getCurrentTimeout = Duration(seconds: 8);

  Future<void> _ensureServiceAndPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException('Servicio de ubicación desactivado');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      throw const LocationException('Permiso de ubicación denegado');
    }
  }

  /// Lectura rápida con timeout y fallback a lastKnown.
  Future<Position> getCurrent() async {
    await _ensureServiceAndPermission();
    final acc = Platform.isIOS
        ? LocationAccuracy.bestForNavigation
        : LocationAccuracy.best;
    try {
      final p = await Geolocator.getCurrentPosition(
        desiredAccuracy: acc,
        timeLimit: _getCurrentTimeout,
      );
      if (!GeoUtils.isValid(p.latitude, p.longitude)) {
        throw const LocationException('Fix inválido (0,0).');
      }
      return p;
    } on TimeoutException {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && GeoUtils.isValid(last.latitude, last.longitude)) {
        return last;
      }
      throw const LocationException(
          'Tiempo de espera agotado obteniendo ubicación');
    } catch (e) {
      throw LocationException('No se pudo obtener la ubicación: $e');
    }
  }

  Future<Position?> getLastKnown() => Geolocator.getLastKnownPosition();

  /// Muestreo de varias lecturas y promedio de las mejores.
  Future<LocationFix> getPreciseFix({
    int samples = 6,
    Duration perSampleTimeout = const Duration(seconds: 4),
    double keepBestFraction = 0.6,
  }) async {
    assert(samples > 0 && keepBestFraction > 0 && keepBestFraction <= 1);

    await _ensureServiceAndPermission();

    final desired = Platform.isIOS
        ? LocationAccuracy.bestForNavigation
        : LocationAccuracy.best;

    final List<Position> bucket = [];
    int discarded = 0;

    for (var i = 0; i < samples; i++) {
      try {
        final p = await Geolocator.getCurrentPosition(
          desiredAccuracy: desired,
        ).timeout(perSampleTimeout);

        if (_validPos(p)) {
          bucket.add(p);
        } else {
          discarded++;
        }
      } on TimeoutException {
        discarded++;
      } catch (_) {
        discarded++;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    if (bucket.isEmpty) {
      throw const LocationException('Sin lecturas de GPS disponibles.');
    }

    bucket.sort((a, b) => a.accuracy.compareTo(b.accuracy));
    final keepNum =
    (bucket.length * keepBestFraction).clamp(1, bucket.length).toInt();
    final kept = bucket.take(keepNum).toList();

    final avgLat =
        kept.map((p) => p.latitude).reduce((a, b) => a + b) / kept.length;
    final avgLng =
        kept.map((p) => p.longitude).reduce((a, b) => a + b) / kept.length;

    if (!GeoUtils.isValid(avgLat, avgLng)) {
      throw const LocationException('Fix inválido (0,0).');
    }

    final dists = kept
        .map((p) => Geolocator.distanceBetween(
      avgLat,
      avgLng,
      p.latitude,
      p.longitude,
    ))
        .toList()
      ..sort();
    final medianDist = dists[dists.length ~/ 2];

    final bestReported = kept.first.accuracy;
    final estAccuracy = (medianDist * 1.4826);
    final accuracy = estAccuracy > bestReported ? estAccuracy : bestReported;

    final ref = kept.first;
    return LocationFix(
      latitude: avgLat,
      longitude: avgLng,
      accuracyMeters: accuracy,
      altitudeMeters: ref.altitude.isFinite ? ref.altitude : null,
      speedMps: ref.speed.isFinite ? ref.speed : null,
      headingDeg: ref.heading.isFinite ? ref.heading : null,
      timestamp: ref.timestamp, // non-null
      usedSamples: kept.length,
      discardedSamples: discarded + (bucket.length - kept.length),
    );
  }

  /// Ultra-fix: calienta por stream + acumula muestras, con timeout total.
  /// Fallback a captureExact si no hay lecturas válidas.
  Future<LocationFix> getUltraFix({
    int maxSamples = 10,
    Duration perSampleTimeout = const Duration(seconds: 4),
    Duration overallTimeout = const Duration(seconds: 18),
    double keepBestFraction = 0.6,
  }) async {
    assert(maxSamples > 0 && keepBestFraction > 0 && keepBestFraction <= 1);

    await _ensureServiceAndPermission();

    final desired = Platform.isIOS
        ? LocationAccuracy.bestForNavigation
        : LocationAccuracy.best;

    final bucket = <Position>[];
    var discarded = 0;

    // Warm-up por stream (no bloqueante)
    final stream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: desired,
        distanceFilter: 0,
      ),
    );
    final sub = stream.listen((pos) {
      if (_validPos(pos)) {
        bucket.add(pos);
      } else {
        discarded++;
      }
    }, onError: (_) {});

    final sw = Stopwatch()..start();
    while (bucket.length < maxSamples && sw.elapsed < overallTimeout) {
      try {
        final p = await Geolocator.getCurrentPosition(
          desiredAccuracy: desired,
        ).timeout(perSampleTimeout);
        if (_validPos(p)) {
          bucket.add(p);
        } else {
          discarded++;
        }
      } on TimeoutException {
        discarded++;
      } catch (_) {
        discarded++;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }

    await sub.cancel();

    // Fallback si no conseguimos nada
    if (bucket.isEmpty) {
      final alt = await captureExact(
        warmup: const Duration(seconds: 7),
        timeout: overallTimeout,
        targetAccuracyMeters: 25,
      );
      if (alt != null && GeoUtils.isValid(alt.latitude, alt.longitude)) {
        return alt;
      }
      throw const LocationException('Sin lecturas válidas');
    }

    bucket.sort((a, b) => a.accuracy.compareTo(b.accuracy));
    final keepNum =
    (bucket.length * keepBestFraction).clamp(1, bucket.length).toInt();
    final kept = bucket.take(keepNum).toList();

    final avgLat =
        kept.map((p) => p.latitude).reduce((a, b) => a + b) / kept.length;
    final avgLng =
        kept.map((p) => p.longitude).reduce((a, b) => a + b) / kept.length;

    if (!GeoUtils.isValid(avgLat, avgLng)) {
      throw const LocationException('Fix inválido (0,0).');
    }

    final dists = kept
        .map((p) => Geolocator.distanceBetween(
      avgLat,
      avgLng,
      p.latitude,
      p.longitude,
    ))
        .toList()
      ..sort();
    final medianDist = dists[dists.length ~/ 2];

    final bestReported = kept.first.accuracy;
    final estAccuracy = (medianDist * 1.4826);
    final accuracy = estAccuracy > bestReported ? estAccuracy : bestReported;

    final ref = kept.first;
    return LocationFix(
      latitude: avgLat,
      longitude: avgLng,
      accuracyMeters: accuracy,
      altitudeMeters: ref.altitude.isFinite ? ref.altitude : null,
      speedMps: ref.speed.isFinite ? ref.speed : null,
      headingDeg: ref.heading.isFinite ? ref.heading : null,
      timestamp: ref.timestamp, // non-null
      usedSamples: kept.length,
      discardedSamples: discarded + (bucket.length - kept.length),
    );
  }

  String mapsUrl(double lat, double lng) =>
      GeoUtils.mapsUri(lat, lng).toString();

  Future<bool> openInMaps({
    required double lat,
    required double lng,
    String? label,
  }) async {
    if (!GeoUtils.isValid(lat, lng)) return false;
    final geo = GeoUtils.geoUri(lat, lng, label: label);
    if (await canLaunchUrl(geo)) {
      return launchUrl(geo, mode: LaunchMode.externalApplication);
    }
    final web = GeoUtils.mapsUri(lat, lng);
    return launchUrl(web, mode: LaunchMode.externalApplication);
  }

  String shareTextFor(double lat, double lng, {String? label}) {
    final ok = GeoUtils.isValid(lat, lng);
    final fLat = ok ? GeoUtils.fmt(lat) : '—';
    final fLng = ok ? GeoUtils.fmt(lng) : '—';
    final geo = ok ? GeoUtils.geoUri(lat, lng, label: label).toString() : '';
    final web = ok ? GeoUtils.mapsUri(lat, lng).toString() : '';
    return 'Ubicación: $fLat, $fLng\n$geo\n$web';
  }

  // ---------- helpers ----------
  bool _validPos(Position p) {
    if (!GeoUtils.isValid(p.latitude, p.longitude)) return false;
    if (!p.accuracy.isFinite || p.accuracy <= 0) return false;
    if (p.isMocked == true) return false;
    return true;
  }
}

extension LocationCapture on LocationService {
  Future<LocationFix?> captureExact({
    Duration warmup = const Duration(seconds: 7),
    Duration timeout = const Duration(seconds: 15),
    double targetAccuracyMeters = 25,
  }) async {
    await _ensureServiceAndPermission();

    Position? best = await Geolocator.getLastKnownPosition();
    if (best != null && !GeoUtils.isValid(best.latitude, best.longitude)) {
      best = null;
    }

    final stream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      ),
    );

    final completer = Completer<Position?>();
    late final StreamSubscription<Position> sub;

    Timer? warmTimer;
    Timer? killTimer;

    void finish(Position? p) async {
      warmTimer?.cancel();
      killTimer?.cancel();
      await sub.cancel();
      if (!completer.isCompleted) completer.complete(p);
    }

    sub = stream.listen((pos) {
      if (pos.isMocked == true) return;
      if (!GeoUtils.isValid(pos.latitude, pos.longitude)) return;

      if (best == null || pos.accuracy < best!.accuracy) {
        best = pos;
        if (pos.accuracy <= targetAccuracyMeters) {
          finish(best);
        }
      }
    }, onError: (_) async {
      try {
        final p = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
          timeLimit: const Duration(seconds: 5),
        );
        if (GeoUtils.isValid(p.latitude, p.longitude)) {
          finish(p);
        } else {
          finish(best);
        }
      } catch (_) {
        finish(best);
      }
    });

    warmTimer = Timer(warmup, () {
      if (best != null && best!.accuracy <= targetAccuracyMeters) {
        finish(best);
      }
    });

    killTimer = Timer(timeout, () => finish(best));

    // Espera principal + fallbacks sin catchError que devuelva null inválido
    Position? primary;
    try {
      primary = await completer.future;
    } catch (_) {
      primary = null;
    }

    Position? fast;
    if (primary == null) {
      try {
        fast = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
          timeLimit: const Duration(seconds: 5),
        );
      } catch (_) {
        fast = null;
      }
    }

    final pos = primary ?? fast ?? best;

    if (pos == null || !GeoUtils.isValid(pos.latitude, pos.longitude)) {
      return null;
    }

    return LocationFix(
      latitude: pos.latitude,
      longitude: pos.longitude,
      accuracyMeters: pos.accuracy,
      altitudeMeters: pos.altitude.isFinite ? pos.altitude : null,
      speedMps: pos.speed.isFinite ? pos.speed : null,
      headingDeg: pos.heading.isFinite ? pos.heading : null,
      timestamp: pos.timestamp, // non-null
      usedSamples: 1,
      discardedSamples: 0,
    );
  }

  Future<LocationFix?> freezeIfEmpty(LocationFix? existing) async {
    if (existing != null) return existing;
    return captureExact();
  }
}
