import 'dart:math' as math;
import 'package:collection/collection.dart';
import '../models/measurement.dart';

class AnomalyFlag {
  AnomalyFlag({required this.key, required this.score, required this.message});
  final String key;   // repo.keyFor(m)
  final double score; // z robusto
  final String message;
}

/// Detección robusta por vecinos espaciales (MAD).
class AnomalyService {
  const AnomalyService({this.radiusMeters = 300, this.minNeighbors = 4});
  final double radiusMeters;
  final int minNeighbors;

  List<AnomalyFlag> find(List<Measurement> items, String Function(Measurement) keyFor) {
    final pts = items.where((m) => m.latitude != null && m.longitude != null).toList();
    final flags = <AnomalyFlag>[];
    for (final m in pts) {
      final v = (m.ohm1m ?? m.ohm3m)?.toDouble();
      if (v == null) continue;

      final neigh = pts.where((o) {
        if (identical(o, m)) return false;
        return _haversine(m.latitude!, m.longitude!, o.latitude!, o.longitude!) <= radiusMeters;
      }).map((o) => (o.ohm1m ?? o.ohm3m)?.toDouble()).whereType<double>().toList();

      if (neigh.length < minNeighbors) continue;

      final med = _median(neigh);
      final absDev = neigh.map((x) => (x - med).abs()).toList();
      final mad = _median(absDev).clamp(1e-6, double.infinity);

      final z = 0.6745 * (v - med).abs() / mad; // z-score robusto
      if (z >= 3.5) {
        flags.add(AnomalyFlag(
          key: keyFor(m),
          score: z,
          message: 'Valor inusual vs. ${neigh.length} vecinos (z≈${z.toStringAsFixed(1)})',
        ));
      }
    }
    flags.sort((a, b) => -a.score.compareTo(b.score));
    return flags;
  }

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
    final a = math.sin(dLat/2)*math.sin(dLat/2) +
        math.cos(toRad(lat1))*math.cos(toRad(lat2))*math.sin(dLon/2)*math.sin(dLon/2);
    return 2 * R * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
