// lib/services/elite_assistant.dart
// IA local “Excel-like”: autocompleta, valida y aprende con Hive.
// No depende de SDKs externos. Pensada para funcionar offline.

import 'package:hive/hive.dart';

import '../models/measurement.dart';
import 'smart_assistant.dart';

class EliteAssistant implements GridnoteAssistant {
  EliteAssistant._(this._boxName);
  final String _boxName;

  static Future<EliteAssistant> forSheet(String sheetId) async {
    final a = EliteAssistant._('brain_$sheetId');
    await a._ensure();
    return a; // Cada planilla tiene su propio “cerebro”.
  }

  Box<Map>? _box;

  Future<void> _ensure() async {
    _box ??= await Hive.openBox<Map>(_boxName);
    if (!(_box!.containsKey('stats'))) {
      await _box!.put('stats', <String, dynamic>{});
    }
  }

  Map<String, dynamic> get _stats =>
      Map<String, dynamic>.from(_box?.get('stats') ?? <String, dynamic>{});

  Future<void> _setStats(Map<String, dynamic> s) async =>
      _box?.put('stats', Map<String, dynamic>.from(s));

  // ========= Aprendizaje por fila (null-safe) =========
  @override
  void learn(Measurement m) {
    final s = Map<String, dynamic>.from(_stats);

    double mean(String k, double v) {
      final m0 = ((s['$k.mean'] ?? 0.0) as num).toDouble();
      final n0 = (s['$k.n'] ?? 0) as int;
      final nm = ((m0 * n0) + v) / (n0 + 1).toDouble();
      s['$k.mean'] = nm;
      s['$k.n'] = n0 + 1;
      return nm;
    }

    void bump(String k, String v) {
      final vv = v.trim();
      if (vv.isEmpty) return;
      final map =
      Map<String, int>.from((s[k] as Map?) ?? <String, int>{});
      map[vv] = (map[vv] ?? 0) + 1;
      s[k] = map;
    }

    final ohm1 = (m.ohm1m as num?)?.toDouble();
    final ohm3 = (m.ohm3m as num?)?.toDouble();
    if (ohm1 != null) mean('ohm1m', ohm1);
    if (ohm3 != null) mean('ohm3m', ohm3);
    if (m.progresiva.isNotEmpty) bump('progresiva.mode', m.progresiva);
    if (m.observations.isNotEmpty) bump('obs.mode', m.observations);

    _setStats(s);
  }

  double _mean(String k, double def) =>
      ((_stats['$k.mean'] ?? def) as num).toDouble();

  // ========= Núcleo de IA =========
  @override
  Future<AiResult> transform(AiCellContext ctx) async {
    await _ensure();
    final col = ctx.columnName;

    // --- PROGRESIVA ---
    if (col == 'progresiva') {
      final raw = (ctx.rawInput ?? '').toString().trim();
      if (raw.isEmpty) {
        if (ctx.rowIndex > 0 && ctx.rows.length > ctx.rowIndex) {
          final prev = ctx.rows[ctx.rowIndex - 1].progresiva;
          return AiResult.accept(_incCode(prev), hint: 'Autocompletado');
        }
        return AiResult.accept('');
      }
      // Limpieza mínima
      final fixed = raw.replaceAll(RegExp(r'\s+'), '').replaceAll('--', '-');
      return AiResult.accept(fixed);
    }

    // --- NÚMEROS (ohm1m / ohm3m) ---
    if (col == 'ohm1m' || col == 'ohm3m') {
      final norm = (ctx.rawInput ?? '').toString().replaceAll(',', '.');
      final v = double.tryParse(norm);
      if (v == null) return AiResult.reject('Número inválido');

      // clamp devuelve num → pasamos a double explícito
      final clamped = v.clamp(0.0, 999999.0).toDouble();

      final hint =
          'Promedio histórico: ${_mean(col, clamped).toStringAsFixed(2)}';
      _teachRunning(col, clamped);
      return AiResult.accept(clamped, hint: hint);
    }

    // --- OBSERVATIONS ---
    if (col == 'observations') {
      final cur = ctx.rows[ctx.rowIndex];
      final prev1 = (cur.ohm1m as num?)?.toDouble() ?? 0.0;
      final prev3 = (cur.ohm3m as num?)?.toDouble() ?? 0.0;
      final mean1 = _mean('ohm1m', prev1);
      final mean3 = _mean('ohm3m', prev3);
      final ok = (prev1 <= mean1 * 1.15) && (prev3 <= mean3 * 1.15);

      final raw = (ctx.rawInput ?? '').toString().trim();
      if (raw.isNotEmpty) return AiResult.accept(raw);

      return AiResult.accept(
        ok ? 'OK' : 'Revisar',
        hint: ok ? 'Dentro de rango' : 'Sobre promedio',
      );
    }

    // --- FECHA ---
    if (col == 'date') {
      final raw = (ctx.rawInput ?? '').toString().trim();
      if (raw.isEmpty) return AiResult.accept(DateTime.now(), hint: 'Hoy');
      final d = _parseDate(raw);
      return (d == null) ? AiResult.reject('Fecha inválida') : AiResult.accept(d);
    }

    // Default
    return AiResult.accept(ctx.rawInput);
  }

  void _teachRunning(String col, double v) {
    final s = Map<String, dynamic>.from(_stats);
    var mean = ((s['$col.mean'] ?? 0.0) as num).toDouble();
    var n = (s['$col.n'] ?? 0) as int;

    mean = ((mean * n) + v) / (n + 1).toDouble();
    n = n + 1;

    s['$col.mean'] = mean;
    s['$col.n'] = n;
    _setStats(s);
  }

  String _incCode(String code) {
    final re = RegExp(r'^(.*?)(\d+)$');
    final m = re.firstMatch(code);
    if (m == null) return code;
    final head = m.group(1)!;
    final numStr = m.group(2)!;
    final n = (int.tryParse(numStr) ?? 0) + 1;
    final padded = n.toString().padLeft(numStr.length, '0');
    return '$head$padded';
  }

  DateTime? _parseDate(String raw) {
    final r = raw.replaceAll('-', '/');
    final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{2,4})$').firstMatch(r);
    if (m == null) return null;
    final d = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    var y = int.parse(m.group(3)!);
    if (y < 100) y += 2000;
    return DateTime(y, mo, d);
  }
}
