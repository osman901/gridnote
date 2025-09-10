// lib/ai/anomaly_service.dart
import 'dart:math' as math;
import 'package:collection/collection.dart';
import '../models/measurement.dart';

class AnomalyFlag {
  AnomalyFlag({required this.key, required this.score, required this.message});
  final String key;   // keyFor(m)
  final double score; // z robusto
  final String message;
}

/// DetecciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n robusta por vecinos espaciales (MAD).
class AnomalyService {
  const AnomalyService({this.radiusMeters = 300, this.minNeighbors = 4});
  final double radiusMeters;
  final int minNeighbors;

  List<AnomalyFlag> find(
      List<Measurement> items,
      String Function(Measurement) keyFor,
      ) {
    // Solo puntos con coordenadas
    final pts = items
        .where((m) => m.latitude != null && m.longitude != null)
        .toList();

    final flags = <AnomalyFlag>[];

    for (final m in pts) {
      final vOpt = _valueOf(m);
      if (vOpt == null) continue; // sin valor para evaluar
      final v = vOpt.toDouble();

      // Vecinos dentro del radio con valores vÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡lidos
      final neigh = pts.where((o) {
        if (identical(o, m)) return false;
        return _haversine(
          m.latitude!, m.longitude!, o.latitude!, o.longitude!,
        ) <=
            radiusMeters;
      }).map(_valueOf).whereType<double>().toList();

      if (neigh.length < minNeighbors) continue;

      final med = _median(neigh);
      final absDev = neigh.map((x) => (x - med).abs()).toList();
      // Evita divisiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n por cero
      final mad = _median(absDev);
      final safeMad = mad <= 1e-12 ? 1e-6 : mad;

      final z = 0.6745 * (v - med).abs() / safeMad; // z-score robusto
      if (z >= 3.5) {
        flags.add(AnomalyFlag(
          key: keyFor(m),
          score: z,
          message:
          'Valor inusual vs. ${neigh.length} vecinos (zÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â°Ãƒâ€¹Ã¢â‚¬ ${z.toStringAsFixed(1)})',
        ));
      }
    }

    flags.sort((a, b) => -a.score.compareTo(b.score));
    return flags;
  }

  /// Prefiere ohm1m y cae a ohm3m. Devuelve null si no hay datos.
  double? _valueOf(Measurement m) => m.ohm1m ?? m.ohm3m;

  double _median(List<double> xs) {
    if (xs.isEmpty) return double.nan;
    final s = xs.sorted((a, b) => a.compareTo(b));
    final mid = s.length ~/ 2;
    return s.length.isOdd ? s[mid] : 0.5 * (s[mid - 1] + s[mid]);
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    double toRad(double d) => d * math.pi / 180.0;
    final dLat = toRad(lat2 - lat1), dLon = toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(toRad(lat1)) *
            math.cos(toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * R * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
