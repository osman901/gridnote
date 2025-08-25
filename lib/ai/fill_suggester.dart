// lib/ai/fill_suggester.dart
import 'package:collection/collection.dart';
import '../models/measurement.dart';
import 'progresiva_utils.dart';

class FillSuggestion {
  FillSuggestion({required this.template, required this.reason});
  final Measurement template; // medición “B” sugerida (sin id)
  final String reason;
}

/// Sugiere “B” si ve huecos A…C en progresivas (step=100) y estima Ohm por promedio de vecinos.
class FillSuggester {
  FillSuggester({this.step = 100});
  final int step;

  List<FillSuggestion> suggest(List<Measurement> items) {
    final withP = items
        .map((m) => (m, Progresiva.parse(m.progresiva)))
        .where((t) => t.$2 != null)
        .map((t) => (t.$1, t.$2!))
        .toList()
      ..sort((a, b) {
        final c = a.$2.km.compareTo(b.$2.km);
        return c != 0 ? c : a.$2.plus.compareTo(b.$2.plus);
      });

    final out = <FillSuggestion>[];
    for (var i = 0; i + 1 < withP.length; i++) {
      final (a, pa) = withP[i];
      final (c, pc) = withP[i + 1];

      if (pa.km == pc.km && pc.plus - pa.plus >= step * 2 && (pc.plus - pa.plus) % step == 0) {
        final missing = (pc.plus - pa.plus) ~/ step - 1;
        for (var j = 1; j <= missing; j++) {
          final pb = Progresiva(pa.km, pa.plus + j * step);

          final neighbors = withP
              .map((e) => e.$1)
              .where((m) => m.ohm1m != null || m.ohm3m != null)
              .sorted((x, y) {
            final dx = ((Progresiva.parse(x.progresiva)?.plus ?? 0) - pb.plus).abs();
            final dy = ((Progresiva.parse(y.progresiva)?.plus ?? 0) - pb.plus).abs();
            return dx.compareTo(dy);
          }).take(4).toList();

          double? ohm1, ohm3;
          if (neighbors.isNotEmpty) {
            final n1 = neighbors.map((m) => m.ohm1m).whereType<double>().toList();
            final n3 = neighbors.map((m) => m.ohm3m).whereType<double>().toList();
            if (n1.isNotEmpty) ohm1 = n1.average; // de package:collection
            if (n3.isNotEmpty) ohm3 = n3.average;
          }

          final lat = (a.latitude != null && c.latitude != null)
              ? a.latitude! + (c.latitude! - a.latitude!) * (j / (missing + 1))
              : null;
          final lng = (a.longitude != null && c.longitude != null)
              ? a.longitude! + (c.longitude! - a.longitude!) * (j / (missing + 1))
              : null;

          final template = Measurement.empty().copyWith(
            date: DateTime.now(),
            progresiva: pb.toString(),
            ohm1m: ohm1,
            ohm3m: ohm3,
            latitude: lat,
            longitude: lng,
          );

          out.add(FillSuggestion(
            template: template,
            reason: 'Hueco detectado entre ${a.progresiva} y ${c.progresiva}',
          ));
        }
      }
    }
    return out;
  }
}
