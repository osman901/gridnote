// lib/services/ai/copilot.dart
import 'package:flutter/widgets.dart';               // BuildContext
import '../../models/measurement.dart';
import '../../models/sheet_meta.dart';
import '../sheet_registry.dart';
import 'planner.dart';
import 'skills.dart';

class CopilotVisionResult {
  final List<Measurement> rows;
  final String summary;
  CopilotVisionResult(this.rows, this.summary);
}

class Copilot {
  Copilot._();
  static final Copilot instance = Copilot._();

  Future<CopilotVisionResult?> quickScan(BuildContext ctx, {SheetMeta? into}) async {
    final planner = CopilotPlanner([
      OcrSkill(),
      ObjectsSkill(),
      GpsSkill(),
      MemorySkill(() async {
        // TODO: cargar desde Hive/SQLite; placeholder:
        return {
          'text_aliases': {'Poste': 'Poste BT'},
          'tags': ['baja-tension'],
        };
      }),
    ]);

    final outcome = await planner.run(CopilotContext());

    final rows = <Measurement>[];
    for (final r in outcome.rows) {
      final map = r.toRowValues();       // Map<String, dynamic>
      rows.add(_toMeasurement(map));     // crea Measurement con campos requeridos
    }

    final summary = 'Propuestas: ${rows.length}. '
        'Confianza ${(outcome.confidence * 100).toStringAsFixed(0)}%.';

    return CopilotVisionResult(rows, summary);
  }

  Future<SheetMeta> commitToSheet(SheetMeta? meta, List<Measurement> rows) async {
    final m = meta ?? await SheetRegistry.instance.create(name: 'Escaneo Copiloto');
    // TODO: persistir rows en tu almacenamiento real
    await SheetRegistry.instance.touch(m);
    return m;
  }
}

// ----------------- helpers -----------------

Measurement _toMeasurement(Map<String, dynamic> v) {
  final String progresiva =
  (v['progresiva'] ?? v['poste'] ?? v['id'] ?? '').toString();

  final double ohm3m = _asDouble(v['ohm3m'] ?? v['R3m'] ?? v['r3m']) ?? 0.0;
  final double ohm1m = _asDouble(v['ohm1m'] ?? v['R1m'] ?? v['r1m']) ?? 0.0;

  final String observations =
  (v['observations'] ?? v['obs'] ?? v['nota'] ?? '').toString();

  final DateTime date =
      _asDate(v['date'] ?? v['fecha']) ?? DateTime.now();

  return Measurement(
    progresiva: progresiva,
    ohm3m: ohm3m,
    ohm1m: ohm1m,
    observations: observations,
    date: date,
  );
}

double? _asDouble(dynamic x) {
  if (x == null) return null;
  if (x is num) return x.toDouble();
  final s = x.toString().replaceAll(',', '.').trim();
  return double.tryParse(s);
}

DateTime? _asDate(dynamic x) {
  if (x == null) return null;
  if (x is DateTime) return x;
  final s = x.toString().trim();
  return DateTime.tryParse(s) ??
      _tryFormats(s, const ['dd-MM-yyyy', 'dd/MM/yyyy', 'yyyy-MM-dd']);
}

DateTime? _tryFormats(String s, List<String> fmts) {
  for (final f in fmts) {
    try {
      if (f == 'dd-MM-yyyy' || f == 'dd/MM/yyyy') {
        final sep = f.contains('-') ? '-' : '/';
        final parts = s.split(sep);
        if (parts.length == 3) {
          final d = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          final y = int.tryParse(parts[2]);
          if (d != null && m != null && y != null) {
            return DateTime(y, m, d);
          }
        }
      } else if (f == 'yyyy-MM-dd') {
        final parts = s.split('-');
        if (parts.length == 3) {
          final y = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          final d = int.tryParse(parts[2]);
          if (d != null && m != null && y != null) {
            return DateTime(y, m, d);
          }
        }
      }
    } catch (_) {}
  }
  return null;
}
