import 'dart:async';
import 'dart:io' show Platform;

import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

/// Error controlado para flujos de ubicación.
class LocationException implements Exception {
  final String message;
  const LocationException(this.message);
  @override
  String toString() => 'LocationException: $message';
}

/// Resultado de ubicación con metadatos útiles.
class LocationFix {
  final double latitude;
  final double longitude;
  final double? accuracyMeters; // radio 68% estimado
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

  /// Formato geo: URI (sirve offline en muchas apps de mapas).
  String toGeoUri({String? label}) {
    final lbl = label == null ? '' : '(${Uri.encodeComponent(label)})';
    // `q=` ayuda a que ciertas apps muestren pin + etiqueta
    return 'geo:$latitude,$longitude?q=$latitude,$longitude$lbl';
  }

  /// URL de Google Maps (online).
  Uri toMapsUri() => Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
  );

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

  /// Verifica servicio y permisos. Lanza [LocationException] si falla.
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

  /// Posición rápida (1 lectura) con alta precisión.
  Future<Position> getCurrent() async {
    await _ensureServiceAndPermission();
    try {
      final acc = Platform.isIOS
          ? LocationAccuracy.bestForNavigation
          : LocationAccuracy.best; // Android: PRIORITY_HIGH_ACCURACY
      return Geolocator.getCurrentPosition(desiredAccuracy: acc);
    } catch (e) {
      throw LocationException('No se pudo obtener la ubicación: $e');
    }
  }

  /// Última conocida (rápida, puede estar vieja). Devuelve `null` si no hay.
  Future<Position?> getLastKnown() => Geolocator.getLastKnownPosition();

  /// Fija precisa por muestreo (mejor que una sola lectura).
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
        bucket.add(p);
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
    final keepNum = (bucket.length * keepBestFraction).clamp(1, bucket.length).toInt();
    final kept = bucket.take(keepNum).toList();

    // Centroide
    final avgLat =
        kept.map((p) => p.latitude).reduce((a, b) => a + b) / kept.length;
    final avgLng =
        kept.map((p) => p.longitude).reduce((a, b) => a + b) / kept.length;

    // Dispersión robusta (MAD en metros)
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

    // Precisión estimada: máx entre mejor accuracy reportada y MAD*1.4826
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
      timestamp: ref.timestamp ?? DateTime.now().toUtc(),
      usedSamples: kept.length,
      discardedSamples: discarded + (bucket.length - kept.length),
    );
  }

  String mapsUrl(double lat, double lng) =>
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

  Future<bool> openInMaps({
    required double lat,
    required double lng,
    String? label,
  }) async {
    final geo = Uri.parse(
      'geo:$lat,$lng?q=$lat,$lng${label == null ? '' : '(${Uri.encodeComponent(label)})'}',
    );
    if (await canLaunchUrl(geo)) {
      return launchUrl(geo, mode: LaunchMode.externalApplication);
    }
    final web = Uri.parse(mapsUrl(lat, lng));
    return launchUrl(web, mode: LaunchMode.externalApplication);
  }

  String shareTextFor(double lat, double lng, {String? label}) {
    final geo =
        'geo:$lat,$lng?q=$lat,$lng${label == null ? '' : '(${Uri.encodeComponent(label)})'}';
    final web = mapsUrl(lat, lng);
    return 'Ubicación: $lat,$lng\n$geo\n$web';
  }
}
