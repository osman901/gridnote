// lib/services/ai/planner.dart
import 'dart:math';
import 'schemas.dart';
import 'skills.dart';

/// Orquestador: ejecuta skills, fusiona señales, valida contra el esquema,
/// calcula confianza y devuelve RowDrafts listos para commit.
class CopilotPlanner {
  final List<CopilotSkill> skills;
  CopilotPlanner(this.skills);

  Future<PlanOutcome> run(CopilotContext ctx) async {
    final bag = <String, dynamic>{};
    final traces = <Trace>[];

    for (final s in skills) {
      final t0 = DateTime.now();
      try {
        final out = await s.invoke(ctx);
        final conf = s.confidence(ctx, out);
        bag[s.name] = out;
        traces.add(Trace(s.name, true, conf, DateTime.now().difference(t0)));
      } catch (e) {
        traces.add(Trace(s.name, false, 0, DateTime.now().difference(t0), err: '$e'));
      }
    }

    // Fusión simple (reglas + “mini-LLM” opcional): prioriza OCR → objetos → memoria → defaults
    final rows = <RowDraft>[];
    final ocr = bag['ocr'] as Map<String, dynamic>? ?? {};
    final objs = bag['objects'] as Map<String, dynamic>? ?? {};
    final gps = bag['gps'] as Map<String, dynamic>? ?? {};
    final mem = bag['memory'] as Map<String, dynamic>? ?? {};

    final desc = (ocr['bestLine'] ?? objs['topClass'] ?? 'Incidencia').toString();
    final lat = gps['lat'] as double?;
    final lng = gps['lng'] as double?;
    final acc = gps['acc'] as double? ?? 30.0;

    final draft = RowDraft(
      descripcion: _applyAliases(desc, mem),
      lat: lat, lng: lng, accuracyM: acc,
      tags: _mergeTags(objs['tags'], ocr['tags'], mem['tags']),
    );

    final validated = draft.validate();
    final conf = _overallConfidence(traces, draft);
    return PlanOutcome([validated], conf, traces);
  }

  String _applyAliases(String text, Map mem) {
    final aliases = (mem['text_aliases'] as Map?) ?? const {};
    for (final e in aliases.entries) {
      if (text.contains(e.key)) return text.replaceAll(e.key, e.value);
    }
    return text;
  }

  List<String> _mergeTags(dynamic a, dynamic b, dynamic c) {
    final set = <String>{};
    void add(x) { if (x is Iterable) set.addAll(x.map((e)=>e.toString())); }
    add(a); add(b); add(c);
    return set.take(6).toList();
  }

  double _overallConfidence(List<Trace> t, RowDraft d) {
    final skillAvg = t.where((x)=>x.ok).map((x)=>x.conf).fold<double>(0,(a,b)=>a+b) / max(1, t.where((x)=>x.ok).length);
    var c = 0.6 * skillAvg;
    if (d.lat != null && d.lng != null) c += 0.2;
    if (d.tags.isNotEmpty) c += 0.1;
    if (d.descripcion.length >= 6) c += 0.1;
    return c.clamp(0, 1);
  }
}

class PlanOutcome {
  final List<RowDraft> rows;
  final double confidence; // 0–1
  final List<Trace> traces;
  PlanOutcome(this.rows, this.confidence, this.traces);
}

class Trace {
  final String skill; final bool ok; final double conf; final Duration dt; final String? err;
  Trace(this.skill, this.ok, this.conf, this.dt, {this.err});
}
