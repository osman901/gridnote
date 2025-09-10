import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show ValueListenable, debugPrint, debugPrintStack;
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

/// Pasá un ValueNotifier<bool>(false) como [CancelToken] si querés cancelación cooperativa.
typedef CancelToken = ValueListenable<bool>;

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
  final double? accuracyMeters; // ~68% radio estimado
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

  factory LocationFix.fromPosition(Position p, {int used = 1, int discarded = 0}) {
    return LocationFix(
      latitude: p.latitude,
      longitude: p.longitude,
      accuracyMeters: _finiteOrNull(p.accuracy),
      altitudeMeters: _finiteOrNull(p.altitude),
      speedMps: _finiteOrNull(p.speed),
      headingDeg: _finiteOrNull(p.heading),
      timestamp: p.timestamp,
      usedSamples: used,
      discardedSamples: discarded,
    );
  }

  static double? _finiteOrNull(double v) => (v.isNaN || v.isInfinite) ? null : v;

  String toGeoUri({String? label}) => _geoUri(latitude, longitude, label: label).toString();
  Uri toMapsUri() => _mapsUri(latitude, longitude);

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

  // Timeouts/umbrales por defecto
  static const Duration _getCurrentTimeout = Duration(seconds: 10);
  static const Duration _lastKnownMaxAge = Duration(minutes: 2);
  static const double _maxAcceptableAccuracyMeters = 150.0;

  // ---------- permisos ----------
  Future<void> _ensureServiceAndPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException('Por favor, activá el servicio de ubicación (GPS) del dispositivo.');
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      throw const LocationException('El permiso de ubicación fue denegado.');
    }
    if (perm == LocationPermission.deniedForever) {
      throw const LocationException('El permiso de ubicación fue denegado permanentemente. Activálo desde los ajustes de la app.');
    }
  }

  Future<bool> hasPermission() async {
    final perm = await Geolocator.checkPermission();
    return perm == LocationPermission.always || perm == LocationPermission.whileInUse;
  }

  Future<bool> ensureFullAccuracy({String? iosPurposeKey}) async {
    final status = await Geolocator.getLocationAccuracy();
    if (status == LocationAccuracyStatus.precise) return true;

    if (Platform.isIOS) {
      try {
        final result = await Geolocator.requestTemporaryFullAccuracy(
          purposeKey: iosPurposeKey ?? 'FullAccuracyUsage',
        );
        return result == LocationAccuracyStatus.precise;
      } catch (_) {}
    }
    return false;
  }

  Future<void> openSystemLocationSettings() => Geolocator.openLocationSettings();
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  // ---------- wrapper moderno ----------
  Future<Position> currentPosition({
    LocationAccuracy accuracy = LocationAccuracy.best,
    Duration? timeout,
    bool tryFullAccuracyIOS = false,
    String? iosPurposeKey,
  }) async {
    await _ensureServiceAndPermission();
    if (tryFullAccuracyIOS && Platform.isIOS) {
      await ensureFullAccuracy(iosPurposeKey: iosPurposeKey);
    }
    final settings = LocationSettings(accuracy: accuracy, timeLimit: timeout);
    return Geolocator.getCurrentPosition(locationSettings: settings);
  }

  // ---------- lecturas rápidas ----------
  Future<LocationFix> getCurrentFix({
    LocationAccuracy? desiredAccuracy,
    Duration timeout = _getCurrentTimeout,
    bool rejectMocked = true,
    bool tryFullAccuracyIOS = false,
    String? iosPurposeKey,
  }) async {
    final p = await getCurrent(
      desiredAccuracy: desiredAccuracy,
      timeout: timeout,
      rejectMocked: rejectMocked,
      tryFullAccuracyIOS: tryFullAccuracyIOS,
      iosPurposeKey: iosPurposeKey,
    );
    return LocationFix.fromPosition(p);
  }

  Future<Position> getCurrent({
    LocationAccuracy? desiredAccuracy,
    Duration timeout = _getCurrentTimeout,
    bool rejectMocked = true,
    bool tryFullAccuracyIOS = false,
    String? iosPurposeKey,
  }) async {
    await _ensureServiceAndPermission();
    if (tryFullAccuracyIOS && Platform.isIOS) {
      await ensureFullAccuracy(iosPurposeKey: iosPurposeKey);
    }

    final acc = desiredAccuracy ??
        (Platform.isIOS ? LocationAccuracy.bestForNavigation : LocationAccuracy.best);

    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: acc, timeLimit: timeout),
      );
      if (!_validPos(p, rejectMocked: rejectMocked)) {
        throw const LocationException('Fix inválido (0,0 o precisión no válida).');
      }
      return p;
    } on TimeoutException {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null &&
          last.timestamp.isAfter(DateTime.now().subtract(_lastKnownMaxAge)) &&
          _validPos(last, rejectMocked: rejectMocked)) {
        return last;
      }
      throw const LocationException('Tiempo agotado. No se obtuvo una ubicación reciente.');
    } catch (e, st) {
      _logError(e, st);
      throw LocationException('No se pudo obtener la ubicación: $e');
    }
  }

  Future<Position?> getLastKnown() => Geolocator.getLastKnownPosition();

  // ---------- lecturas precisas por muestras ----------
  Future<LocationFix> getPreciseFix({
    int samples = 8,
    Duration perSampleTimeout = const Duration(seconds: 4),
    double keepBestFraction = 0.5,
    bool rejectMocked = true,
    double minUniqueMeters = 0.5,
    LocationAccuracy? desiredAccuracy,
    bool tryFullAccuracyIOS = false,
    String? iosPurposeKey,
    CancelToken? cancelToken,
  }) async {
    assert(samples > 0 && keepBestFraction > 0 && keepBestFraction <= 1);
    await _ensureServiceAndPermission();
    _throwIfCancelled(cancelToken);

    if (tryFullAccuracyIOS && Platform.isIOS) {
      await ensureFullAccuracy(iosPurposeKey: iosPurposeKey);
    }

    final desired = desiredAccuracy ??
        (Platform.isIOS ? LocationAccuracy.bestForNavigation : LocationAccuracy.best);

    final List<Position> bucket = <Position>[];
    int discarded = 0;
    Position? lastAccepted;

    for (var i = 0; i < samples; i++) {
      _throwIfCancelled(cancelToken);
      try {
        final p = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(accuracy: desired, timeLimit: perSampleTimeout),
        );

        if (_validPos(p, rejectMocked: rejectMocked)) {
          final la = lastAccepted;
          if (la == null ||
              Geolocator.distanceBetween(la.latitude, la.longitude, p.latitude, p.longitude) >=
                  minUniqueMeters) {
            bucket.add(p);
            lastAccepted = p;
          } else {
            discarded++;
          }
        } else {
          discarded++;
        }
      } on TimeoutException {
        discarded++;
      } catch (_) {
        discarded++;
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    if (bucket.isEmpty) {
      throw const LocationException('No se obtuvieron lecturas de GPS válidas.');
    }

    return _processLocationBucketWeighted(
      bucket: bucket,
      discardedCount: discarded,
      keepBestFraction: keepBestFraction,
    );
  }

  // ---------- utilidades ----------
  Future<bool> openInMaps({required double lat, required double lng, String? label}) async {
    if (!_isValid(lat, lng)) return false;
    final geo = _geoUri(lat, lng, label: label);
    if (await canLaunchUrl(geo)) {
      return launchUrl(geo, mode: LaunchMode.externalApplication);
    }
    final web = _mapsUri(lat, lng);
    return launchUrl(web, mode: LaunchMode.externalApplication);
  }

  /// Helper solicitado por la UI.
  String mapsUrl(double lat, double lng) => _mapsUri(lat, lng).toString();

  String shareTextFor(double lat, double lng, {String? label}) {
    final ok = _isValid(lat, lng);
    final fLat = ok ? _fmt(lat) : '-';
    final fLng = ok ? _fmt(lng) : '-';
    final geo = ok ? _geoUri(lat, lng, label: label).toString() : '';
    final web = ok ? _mapsUri(lat, lng).toString() : '';
    return 'Ubicación: $fLat, $fLng\n$geo\n$web';
  }

  bool _validPos(Position p, {bool rejectMocked = true}) {
    if (!_isValid(p.latitude, p.longitude)) return false;
    if (!p.accuracy.isFinite || p.accuracy <= 0 || p.accuracy > _maxAcceptableAccuracyMeters) {
      return false;
    }
    if (rejectMocked && p.isMocked == true) return false;
    return true;
  }

  void _throwIfCancelled(CancelToken? t) {
    if (t?.value == true) {
      throw const LocationException('Operación cancelada por el usuario.');
    }
  }

  // ---------- Procesamiento de muestras ----------
  LocationFix _processLocationBucketWeighted({
    required List<Position> bucket,
    required int discardedCount,
    required double keepBestFraction,
  }) {
    bucket.sort((a, b) => a.accuracy.compareTo(b.accuracy));
    final int keepNum = (bucket.length * keepBestFraction).clamp(1, bucket.length).toInt();
    final List<Position> kept = bucket.take(keepNum).toList();

    double totalWeight = 0;
    double weightedLat = 0;
    double weightedLng = 0;

    for (final p in kept) {
      final double weight = 1.0 / ((p.accuracy * p.accuracy) + 1e-9); // 1/var
      totalWeight += weight;
      weightedLat += p.latitude * weight;
      weightedLng += p.longitude * weight;
    }

    if (totalWeight == 0) {
      return _processLocationBucket(
        bucket: bucket,
        discardedCount: discardedCount,
        keepBestFraction: keepBestFraction,
      );
    }

    final double avgLat = weightedLat / totalWeight;
    final double avgLng = weightedLng / totalWeight;
    if (!_isValid(avgLat, avgLng)) {
      throw const LocationException('Fix inválido después de procesar (0,0).');
    }

    final Position ref = kept.first;
    final double bestReported = kept.first.accuracy;

    return LocationFix(
      latitude: avgLat,
      longitude: avgLng,
      accuracyMeters: LocationFix._finiteOrNull(bestReported),
      altitudeMeters: LocationFix._finiteOrNull(ref.altitude),
      speedMps: LocationFix._finiteOrNull(ref.speed),
      headingDeg: LocationFix._finiteOrNull(ref.heading),
      timestamp: ref.timestamp,
      usedSamples: kept.length,
      discardedSamples: discardedCount + (bucket.length - kept.length),
    );
  }

  LocationFix _processLocationBucket({
    required List<Position> bucket,
    required int discardedCount,
    required double keepBestFraction,
  }) {
    bucket.sort((a, b) => a.accuracy.compareTo(b.accuracy));
    final int keepNum = (bucket.length * keepBestFraction).clamp(1, bucket.length).toInt();
    final List<Position> kept = bucket.take(keepNum).toList();

    final double avgLat = kept.map((p) => p.latitude).reduce((a, b) => a + b) / kept.length;
    final double avgLng = kept.map((p) => p.longitude).reduce((a, b) => a + b) / kept.length;

    if (!_isValid(avgLat, avgLng)) {
      throw const LocationException('Fix inválido (0,0).');
    }

    // MAD -> sigma aprox (1.4826)
    final List<double> dists = kept
        .map((p) => Geolocator.distanceBetween(avgLat, avgLng, p.latitude, p.longitude))
        .toList()
      ..sort();
    final double medianDist = dists[dists.length ~/ 2];
    final double estAccuracy = medianDist * 1.4826;
    final double bestReported = kept.first.accuracy;
    final double accuracy = estAccuracy > bestReported ? estAccuracy : bestReported;

    final Position ref = kept.first;
    return LocationFix(
      latitude: avgLat,
      longitude: avgLng,
      accuracyMeters: LocationFix._finiteOrNull(accuracy),
      altitudeMeters: LocationFix._finiteOrNull(ref.altitude),
      speedMps: LocationFix._finiteOrNull(ref.speed),
      headingDeg: LocationFix._finiteOrNull(ref.heading),
      timestamp: ref.timestamp,
      usedSamples: kept.length,
      discardedSamples: discardedCount + (bucket.length - kept.length),
    );
  }

  void _logError(Object e, StackTrace st) {
    debugPrint('LocationService error: $e');
    debugPrintStack(stackTrace: st);
  }
}

// ---------- Helpers internos ----------
bool _isValid(double lat, double lng) =>
    lat.isFinite &&
        lng.isFinite &&
        (lat.abs() > 1e-6 || lng.abs() > 1e-6) &&
        lat.abs() <= 90 &&
        lng.abs() <= 180;

String _fmt(double v) => v.toStringAsFixed(6);

Uri _geoUri(double lat, double lng, {String? label}) {
  final labelPart = (label == null || label.trim().isEmpty) ? '' : '(${Uri.encodeComponent(label)})';
  return Uri.parse('geo:${_fmt(lat)},${_fmt(lng)}$labelPart');
}

Uri _mapsUri(double lat, double lng) =>
    Uri.parse('https://www.google.com/maps/search/?api=1&query=${_fmt(lat)},${_fmt(lng)}');
