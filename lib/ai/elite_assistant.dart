// lib/ai/elite_assistant.dart
// EliteAssistant – versión “beta-ready”
// - IA offline con aprendizaje incremental (Hive)
// - Outliers con z-score y ratio configurables (persistidos)
// - Cacheo de estadísticas por sesión con enfriamiento para alta performance
// - Autocompletado y normalización robusta
// - Soporte opcional para LLM externo (inyectable)

import 'dart:math' as math;
import 'package:hive/hive.dart';
import '../models/measurement.dart';
import 'smart_assistant.dart';

typedef LlmSuggestFn = Future<String?> Function({
required String column,
required String contextText,
});

class EliteAssistant implements GridnoteAssistant {
  EliteAssistant._(this._boxName, {this.llmSuggest});
  final String _boxName;
  final LlmSuggestFn? llmSuggest;

  // ===== Persistencia (Hive) =====
  static const _kStats = 'stats';
  static const _kConfig = 'config';
  static const _kCorrPrefix = 'corr.'; // correcciones aprendidas por columna

  Box<Map>? _box;

  Future<void> _ensure() async {
    _box ??= await Hive.openBox<Map>(_boxName);
    if (!(_box!.containsKey(_kStats))) {
      await _box!.put(_kStats, <String, dynamic>{});
    }
    if (!(_box!.containsKey(_kConfig))) {
      await _box!.put(_kConfig, <String, dynamic>{
        'zThreshold': 3.0,
        'minRatio': 0.5,
        'maxRatio': 1.5,
      });
    }
  }

  Map get _stats => _box?.get(_kStats) ?? <String, dynamic>{};
  Map get _config => _box?.get(_kConfig) ?? <String, dynamic>{};

  Future<void> _setStats(Map s) async =>
      _box?.put(_kStats, Map<String, dynamic>.from(s));
  Future<void> _setConfig(Map c) async =>
      _box?.put(_kConfig, Map<String, dynamic>.from(c));

  // ===== Umbrales configurables (persistidos) =====
  double get zThreshold =>
      ((_config['zThreshold'] ?? 3.0) as num).toDouble();
  double get minRatio =>
      ((_config['minRatio'] ?? 0.5) as num).toDouble();
  double get maxRatio =>
      ((_config['maxRatio'] ?? 1.5) as num).toDouble();

  void setOutlierThresholds({double? zThreshold, double? minRatio, double? maxRatio}) {
    final c = Map<String, dynamic>.from(_config);
    if (zThreshold != null) c['zThreshold'] = zThreshold;
    if (minRatio != null) c['minRatio'] = minRatio;
    if (maxRatio != null) c['maxRatio'] = maxRatio;
    _setConfig(c);
  }

  // ===== Construcción =====
  static Future<EliteAssistant> forSheet(
      String sheetId, {
        LlmSuggestFn? llmSuggest,
      }) async {
    final a = EliteAssistant._('brain_$sheetId', llmSuggest: llmSuggest);
    await a._ensure();
    return a;
  }

  // ===== Cache de estadísticas de sesión =====
  // Recalcula a lo sumo cada _statsCooldown o si cambia la longitud.
  final Duration _statsCooldown = const Duration(milliseconds: 350);
  DateTime _lastStatsAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _sessionLen = -1;
  final Map<String, double> _sessionMeans = {};
  final Map<String, double> _sessionStdDevs = {};

  void _ensureSessionStats(AiCellContext ctx) {
    final now = DateTime.now();
    final len = ctx.rows.length;
    final stillFresh =
        now.difference(_lastStatsAt) < _statsCooldown && len == _sessionLen;
    if (stillFresh) return;

    List<double> _col(String col) {
      final vals = <double>[];
      for (final r in ctx.rows) {
        final v = (col == 'ohm1m'
            ? (r.ohm1m as num?)
            : (r.ohm3m as num?))
            ?.toDouble();
        if (v != null) vals.add(v);
      }
      return vals;
    }

    (double mean, double std) _statsFor(List<double> serie) {
      if (serie.length < 5) return (double.nan, double.nan);
      final n = serie.length.toDouble();
      final sum = serie.fold<double>(0, (a, b) => a + b);
      final mean = sum / n;
      double acc = 0;
      for (final v in serie) {
        final d = v - mean;
        acc += d * d;
      }
      final var_ = acc / (n - 1);
      final std = var_ <= 0 ? double.nan : math.sqrt(var_);
      return (mean, std);
    }

    final s1 = _col('ohm1m');
    final s3 = _col('ohm3m');

    final (m1, sd1) = _statsFor(s1);
    final (m3, sd3) = _statsFor(s3);

    _sessionMeans['ohm1m'] = m1;
    _sessionMeans['ohm3m'] = m3;
    _sessionStdDevs['ohm1m'] = sd1;
    _sessionStdDevs['ohm3m'] = sd3;

    _sessionLen = len;
    _lastStatsAt = now;
  }

  // ===== Aprendizaje incremental de uso =====
  void learn(Measurement m) {
    final s = Map<String, dynamic>.from(_stats);

    double mean(String k, double v) {
      final m0 = (s['$k.mean'] ?? 0.0) as double;
      final n0 = (s['$k.n'] ?? 0) as int;
      final nm = (m0 * n0 + v) / math.max(1, n0 + 1);
      s['$k.mean'] = nm;
      s['$k.n'] = n0 + 1;
      return nm;
    }

    void bump(String k, String v) {
      final map = Map<String, int>.from(
          (s[k] ?? <String, int>{}) as Map? ?? {});
      final vv = v.trim();
      if (vv.isEmpty) return;
      map[vv] = (map[vv] ?? 0) + 1;
      s[k] = map;
    }

    final ohm1 = (m.ohm1m as num?)?.toDouble();
    final ohm3 = (m.ohm3m as num?)?.toDouble();

    if (ohm1 != null) mean('ohm1m', ohm1);
    if (ohm3 != null) mean('ohm3m', ohm3);
    if (m.progresiva.isNotEmpty) bump('progresiva.mode', m.progresiva);
    if (m.observations.isNotEmpty) bump('obs.mode', m.observations);

    s['use.rows.edited'] = ((s['use.rows.edited'] ?? 0) as int) + 1;
    _setStats(s);
  }

  double _historicalMean(String k, double def) =>
      ((_stats['$k.mean'] ?? def) as num).toDouble();

  List<String> _topPhrases(String key, {int k = 3}) {
    final m = Map<String, int>.from(
        (_stats[key] ?? const <String, int>{}) as Map? ?? {});
    final items = m.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return items.take(k).map((e) => e.key).toList();
  }

  // ===== Núcleo =====
  @override
  Future<AiResult> transform(AiCellContext ctx) async {
    await _ensure();
    final col = ctx.columnName;
    final raw = (ctx.rawInput ?? '').toString().trim();

    // Mantener stats de sesión frescas (barato por enfriamiento)
    _ensureSessionStats(ctx);

    // --- PROGRESIVA ---
    if (col == 'progresiva') {
      if (raw.isEmpty) {
        final prev = (ctx.rowIndex > 0 && ctx.rows.length > ctx.rowIndex)
            ? ctx.rows[ctx.rowIndex - 1].progresiva
            : '';
        if (prev.isNotEmpty) {
          final nextCode = _incCode(prev);
          final modes = _topPhrases('progresiva.mode');
          return AiResult.accept(
            nextCode,
            hint: _mkHint([
              'Autocompletado: $nextCode',
              if (modes.isNotEmpty) 'Frecuentes: ${modes.join(' · ')}',
            ]),
          );
        }
        final modes = _topPhrases('progresiva.mode');
        return AiResult.accept(
          '',
          hint: _mkHint([
            if (modes.isNotEmpty) 'Usadas: ${modes.join(' · ')}',
            'Tip: KP-001 → KP-002',
          ]),
        );
      }
      final fixed =
      raw.replaceAll(RegExp(r'\s+'), '').replaceAll('--', '-');
      if (fixed != raw) _rememberCorrection(col, raw, fixed);
      return AiResult.accept(fixed, hint: 'OK');
    }

    // --- NÚMEROS (ohm1m / ohm3m) ---
    if (col == 'ohm1m' || col == 'ohm3m') {
      final norm = _normalizeNumber(raw);
      final v = double.tryParse(norm);
      if (v == null) {
        final learned = _lookupCorrection(col, raw);
        final cands = _numericCandidates(raw);
        final msg = [
          'Número inválido',
          if (learned != null) 'Aprendido: $learned',
          if (cands.isNotEmpty) 'Quizás: ${cands.join(' · ')}',
        ].join(' · ');
        return AiResult.reject(msg);
      }

      final clamped = v.clamp(0.0, 999999.0).toDouble();

      // Media histórica (persistida) para contexto de usuario
      final histMean = _historicalMean(col, clamped);

      // z-score basado en stats de sesión (rápido por cache)
      final sessMean = _sessionMeans[col] ?? double.nan;
      final sessStd = _sessionStdDevs[col] ?? double.nan;
      double z = double.nan;
      if (!sessMean.isNaN && sessStd.isFinite && sessStd > 0) {
        z = (clamped - sessMean) / sessStd;
      }

      final extras = <String>[
        'Promedio histórico: ${histMean.toStringAsFixed(2)}',
        if (!z.isNaN && z.abs() >= zThreshold)
          'Muy fuera de rango (≥${zThreshold.toStringAsFixed(1)}σ)'
        else if (!z.isNaN && z.abs() >= zThreshold * 2 / 3)
          'Atención: outlier (z=${z.toStringAsFixed(2)})',
      ];

      final r = _ratio(ctx);
      if (r != null) {
        if (r > maxRatio || r < minRatio) {
          extras.add('Relación 3m/1m fuera de límites');
        } else {
          extras.add('Relación 3m/1m≈${r.toStringAsFixed(2)}');
        }
      }

      if (norm != raw) _rememberCorrection(col, raw, norm);
      _teachRunning(col, clamped);

      return AiResult.accept(clamped, hint: _mkHint(extras));
    }

    // --- OBSERVATIONS (predicción corta) ---
    if (col == 'observations') {
      if (raw.isNotEmpty) {
        _bumpPhrase('obs.mode', raw);
        return AiResult.accept(raw, hint: _mkHint(_obsHints(ctx)));
      }

      final prev1 = (ctx.rows[ctx.rowIndex].ohm1m as num?)?.toDouble();
      final prev3 = (ctx.rows[ctx.rowIndex].ohm3m as num?)?.toDouble();
      final mean1 = _historicalMean('ohm1m', prev1 ?? 0);
      final mean3 = _historicalMean('ohm3m', prev3 ?? 0);
      final ok = ((prev1 ?? mean1) <= mean1 * 1.15) &&
          ((prev3 ?? mean3) <= mean3 * 1.15);

      final top = _topPhrases('obs.mode');
      final base = ok ? 'OK' : 'Revisar';
      final localGuess =
      (top.isNotEmpty && top.first != base) ? top.first : base;

      // LLM opcional
      String? llmSuggestion;
      final call = llmSuggest;
      if (call != null) {
        final res = await call(
          column: 'observations',
          contextText: _mkObservationsPrompt(ctx, fallback: localGuess),
        );
        var cleaned = res?.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
        if (cleaned != null && cleaned.length > 48) {
          cleaned = cleaned.substring(0, 48).trim();
        }
        llmSuggestion = cleaned;
      }
      final chosen = (llmSuggestion != null && llmSuggestion.isNotEmpty)
          ? llmSuggestion
          : localGuess;

      _bumpPhrase('obs.mode', chosen);
      return AiResult.accept(
        chosen,
        hint: _mkHint([
          if (ok) 'Dentro de rango' else 'Sobre promedio',
          if (top.isNotEmpty) 'Frecuentes: ${top.join(' · ')}',
          if (llmSuggestion != null) 'LLM: $llmSuggestion',
        ]),
      );
    }

    // --- FECHA ---
    if (col == 'date') {
      if (raw.isEmpty) return AiResult.accept(DateTime.now(), hint: 'Hoy');
      final d = _parseDate(raw);
      return (d == null)
          ? AiResult.reject('Fecha inválida (dd/mm/aaaa)')
          : AiResult.accept(d, hint: 'OK');
    }

    // Default (eco con normalización básica si aplica)
    return AiResult.accept(raw);
  }

  // ===== Razón/consistencia auxiliar =====
  double? _ratio(AiCellContext ctx) {
    final a = (ctx.rows[ctx.rowIndex].ohm1m as num?)?.toDouble();
    final b = (ctx.rows[ctx.rowIndex].ohm3m as num?)?.toDouble();
    if (a == null || b == null || a == 0) return null;
    return b / a;
  }

  List<String> _obsHints(AiCellContext ctx) {
    final hints = <String>[];
    final r = _ratio(ctx);
    if (r != null) {
      if (r > maxRatio) hints.add('3m muy alto vs 1m → verificar conexión');
      if (r < minRatio) hints.add('3m muy bajo vs 1m → revisar medición');
    }
    return hints;
  }

  // ===== Normalizaciones & utilitarios =====
  String _normalizeNumber(String raw) {
    var s = raw.trim().toLowerCase();
    s = s.replaceAll(',', '.');
    s = s.replaceAll(RegExp(r'[^0-9.\-e]'), '');
    s = s.replaceAll('..', '.').replaceAll('--', '-');
    return s;
  }

  List<String> _numericCandidates(String raw) {
    final cands = <String>{};
    final base = raw.trim();
    cands.add(_normalizeNumber(base.replaceAll('o', '0')));
    cands.add(_normalizeNumber(base.replaceAll('O', '0')));
    cands.add(_normalizeNumber(base.replaceAll(',', '.')));
    cands.add(_normalizeNumber(base.replaceAll('..', '.')));
    return cands.where((e) => double.tryParse(e) != null).take(3).toList();
  }

  void _teachRunning(String col, double v) {
    final s = Map<String, dynamic>.from(_stats);
    double m0 = (s['$col.mean'] ?? 0.0) as double;
    int n0 = (s['$col.n'] ?? 0) as int;
    m0 = (m0 * n0 + v) / math.max(1, n0 + 1);
    n0 = n0 + 1;
    s['$col.mean'] = m0;
    s['$col.n'] = n0;
    _setStats(s);
  }

  void _bumpPhrase(String key, String phrase) {
    final s = Map<String, dynamic>.from(_stats);
    final map =
    Map<String, int>.from((s[key] ?? <String, int>{}) as Map? ?? {});
    final norm = phrase.trim();
    if (norm.isEmpty) return;
    map[norm] = (map[norm] ?? 0) + 1;
    s[key] = map;
    _setStats(s);
  }

  void _rememberCorrection(String col, String raw, String fixed) {
    final key = '$_kCorrPrefix$col';
    final s = Map<String, dynamic>.from(_stats);
    final map = Map<String, String>.from((s[key] ?? const <String, String>{}) as Map? ?? {});
    final r = raw.trim();
    final f = fixed.trim();
    if (r.isEmpty || f.isEmpty) return;
    map[r] = f;
    s[key] = map;
    _setStats(s);
  }

  String? _lookupCorrection(String col, String raw) {
    final key = '$_kCorrPrefix$col';
    final s = Map<String, dynamic>.from(_stats);
    final map = Map<String, String>.from((s[key] ?? const <String, String>{}) as Map? ?? {});
    return map[raw.trim()];
  }

  String _incCode(String code) {
    // BUGFIX: quitar '\$' literal -> anclar con '$'
    final re = RegExp(r'^(.*?)(\d+)([A-Za-z]*)$');
    final m = re.firstMatch(code);
    if (m == null) return code;
    final head = m.group(1)!;
    final numStr = m.group(2)!;
    final tail = m.group(3)!;
    final n = (int.tryParse(numStr) ?? 0) + 1;
    final padded = n.toString().padLeft(numStr.length, '0');
    return '$head$padded$tail';
  }

  DateTime? _parseDate(String raw) {
    final r = raw.replaceAll('-', '/');
    // BUGFIX: quitar '\$' literal -> anclar con '$'
    final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{2,4})$').firstMatch(r);
    if (m == null) return null;
    final d = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    var y = int.parse(m.group(3)!);
    if (y < 100) y += 2000;
    return DateTime(y, mo, d);
  }

  String _mkHint(List<String> parts) =>
      parts.where((e) => e.trim().isNotEmpty).join(' · ');

  String _mkObservationsPrompt(AiCellContext ctx, {required String fallback}) {
    final r = ctx.rows[ctx.rowIndex];
    final d1 = (r.ohm1m as num?)?.toDouble();
    final d3 = (r.ohm3m as num?)?.toDouble();
    final mean1 = _historicalMean('ohm1m', d1 ?? 0);
    final mean3 = _historicalMean('ohm3m', d3 ?? 0);
    final delta1 = d1 == null ? 0 : (d1 - mean1);
    final delta3 = d3 == null ? 0 : (d3 - mean3);

    String fmt(num? v) => v == null ? '-' : v.toStringAsFixed(3);

    return '''
Sos un asistente de planillas tipo Excel. Proponé una observación corta y útil (máx 4 palabras).
Datos:
- ohm1m=${fmt(d1)} (Δ=${delta1.toStringAsFixed(3)})
- ohm3m=${fmt(d3)} (Δ=${delta3.toStringAsFixed(3)})
- Preferencias del usuario: ${_topPhrases('obs.mode').join(', ')}
Si todo está normal, sugerí "OK". Si está alto, sugerí "Revisar".
Si dudás, devolvé: $fallback
''';
  }
}
