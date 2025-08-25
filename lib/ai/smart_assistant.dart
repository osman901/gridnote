// lib/ai/smart_assistant.dart
import '../models/measurement.dart';
import '../widgets/measurement_columns.dart';

/// Contexto de edición de celda.
class AiCellContext {
  AiCellContext({
    required this.columnName,
    required this.rowIndex,
    required this.rawInput,
    required this.oldValue,
    required this.rows,
    this.sheetLat,
    this.sheetLng,
    DateTime? now,
  }) : now = (now ?? DateTime.now()).toUtc();

  final String columnName;
  final int rowIndex;
  final dynamic rawInput;
  final dynamic oldValue;
  final List<Measurement> rows;
  final double? sheetLat;
  final double? sheetLng;
  final DateTime now;
}

/// Resultado de transformación/validación.
class AiResult {
  AiResult.accept(this.value, {this.hint})
      : accept = true,
        error = null;
  AiResult.reject(this.error, {this.hint})
      : accept = false,
        value = null;

  final bool accept;
  final dynamic value;
  final String? hint;
  final String? error;
}

/// Contrato de cualquier asistente (reglas/LLM).
abstract class GridnoteAssistant {
  Future<AiResult> transform(AiCellContext ctx);
}

/// Config global de reglas.
class RuleConfig {
  const RuleConfig({
    this.progressiveStep = 10,
    this.observationMacros = const {
      '#ok': 'OK – sin novedades.',
      '#fallo': 'Falla detectada, revisar conexión y puesta a tierra.',
      '#revisar': 'Requiere revisión en próxima visita.',
      '#gps': '<gps>',
      '#dup': 'Duplicado según planilla anterior.',
    },
    this.statsIgnoreZeros = true,
  });

  final num progressiveStep;
  final Map<String, String> observationMacros;
  final bool statsIgnoreZeros;
}

/// ─────────────────────────── Chain of Responsibility ──────────────────────────
abstract class RuleHandler {
  RuleHandler? _next;
  void setNext(RuleHandler next) => _next = next;

  Future<AiResult?> tryHandle(AiCellContext ctx, String raw) async {
    final r = await process(ctx, raw);
    return r ?? await _next?.tryHandle(ctx, raw);
  }

  Future<AiResult?> process(AiCellContext ctx, String raw);
}

/// Helpers puros / regex precompiladas.
class _AiUtil {
  static final RegExp opRegex = RegExp(
      r'^([+-]?\d+(?:\.\d+)?[km]?)\s*([+\-*/])\s*([+-]?\d+(?:\.\d+)?[km]?)$');
  static final RegExp numWithUnitRegex =
  RegExp(r'^[+-]?\d+(?:\.\d+)?[km]?$');
  static final RegExp dateRegex =
  RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})$');
  static final RegExp relDaysRegex = RegExp(r'^[+-]\d+$');
  static final RegExp statsNoArg =
  RegExp(r'^(sum|avg|max|min|median)\(\)$', caseSensitive: false);
  static final RegExp statsWithArg =
  RegExp(r'^(sum|avg|max|min|median)\((\d+)\)$', caseSensitive: false);

  static double? parseWithUnit(String s) {
    s = s.trim().toLowerCase().replaceAll(',', '.');
    double factor = 1.0;
    if (s.endsWith('k')) {
      factor = 1000.0;
      s = s.substring(0, s.length - 1);
    } else if (s.endsWith('m')) {
      factor = 0.001;
      s = s.substring(0, s.length - 1);
    }
    final n = double.tryParse(s);
    return n == null ? null : n * factor;
  }

  static DateTime? safeDateUtc(int y, int m, int d) {
    final dt = DateTime.utc(y, m, d);
    return (dt.year == y && dt.month == m && dt.day == d) ? dt : null;
  }

  static Iterable<double> columnOhms(AiCellContext ctx) sync* {
    if (ctx.columnName == MeasurementColumn.ohm1m) {
      for (final r in ctx.rows) yield r.ohm1m;
    } else if (ctx.columnName == MeasurementColumn.ohm3m) {
      for (final r in ctx.rows) yield r.ohm3m;
    }
  }

  static double median(List<double> v) {
    if (v.isEmpty) return 0.0;
    v.sort();
    final mid = v.length ~/ 2;
    return v.length.isOdd ? v[mid] : (v[mid - 1] + v[mid]) / 2.0;
  }

  /// #gps seguro incluso en “fila fantasma”.
  static String? gpsText(AiCellContext ctx) {
    double? lat, lng;
    if (ctx.rowIndex >= 0 && ctx.rowIndex < ctx.rows.length) {
      lat = ctx.rows[ctx.rowIndex].latitude ?? ctx.sheetLat;
      lng = ctx.rows[ctx.rowIndex].longitude ?? ctx.sheetLng;
    } else {
      lat = ctx.sheetLat;
      lng = ctx.sheetLng;
    }
    if (lat == null || lng == null) return null;
    return 'GPS: $lat,$lng';
  }
}

/// ───────────────────────────── Handlers concretos ─────────────────────────────

/// "=" → copia valor de misma columna en la fila anterior.
class CopyPreviousHandler extends RuleHandler {
  @override
  Future<AiResult?> process(AiCellContext ctx, String raw) async {
    if (raw != '=') return null;
    if (ctx.rowIndex <= 0) {
      return AiResult.reject('No hay fila anterior para copiar.');
    }
    final prev = ctx.rows[ctx.rowIndex - 1];
    dynamic v;
    switch (ctx.columnName) {
      case MeasurementColumn.progresiva:
        v = prev.progresiva;
        break;
      case MeasurementColumn.ohm1m:
        v = prev.ohm1m;
        break;
      case MeasurementColumn.ohm3m:
        v = prev.ohm3m;
        break;
      case MeasurementColumn.observations:
        v = prev.observations;
        break;
      case MeasurementColumn.date:
        v = prev.date;
        break;
      default:
        v = ctx.rawInput;
    }
    return AiResult.accept(v, hint: 'Copiado de la fila anterior.');
  }
}

/// “auto”/vacío en Progresiva.
class AutoProgresivaHandler extends RuleHandler {
  AutoProgresivaHandler(this.config);
  final RuleConfig config;

  @override
  Future<AiResult?> process(AiCellContext ctx, String raw) async {
    if (ctx.columnName != MeasurementColumn.progresiva) return null;
    final isAuto = raw.toLowerCase() == 'auto' || raw.isEmpty;

    if (ctx.rowIndex == 0 && isAuto) {
      final start = config.progressiveStep.toString();
      return AiResult.accept(start, hint: 'Progresiva auto (inicio): $start');
    }
    if (isAuto && ctx.rowIndex > 0) {
      final prev = ctx.rows[ctx.rowIndex - 1].progresiva.trim();
      final num? n = num.tryParse(prev.replaceAll(',', '.'));
      if (n != null) {
        final next = (n + config.progressiveStep).toString();
        return AiResult.accept(next,
            hint:
            'Progresiva auto: $prev + ${config.progressiveStep} → $next');
      }
      if (prev.isNotEmpty) {
        return AiResult.accept(prev,
            hint: 'Progresiva copiada de la fila anterior.');
      }
    }
    return null;
  }
}

/// Aritmética con unidades por operando en Ω.
class OhmsArithmeticHandler extends RuleHandler {
  @override
  Future<AiResult?> process(AiCellContext ctx, String raw) async {
    if (ctx.columnName != MeasurementColumn.ohm1m &&
        ctx.columnName != MeasurementColumn.ohm3m) return null;

    final s = raw.toLowerCase().replaceAll(',', '.').trim();
    final m = _AiUtil.opRegex.firstMatch(s);
    if (m == null) return null;

    final a = _AiUtil.parseWithUnit(m.group(1)!);
    final op = m.group(2)!;
    final b = _AiUtil.parseWithUnit(m.group(3)!);
    if (a == null || b == null) {
      return AiResult.reject('Operando inválido.',
          hint: 'Ej: 1.2k + 500, 10/4, 3m*2');
    }

    double val;
    switch (op) {
      case '+':
        val = a + b;
        break;
      case '-':
        val = a - b;
        break;
      case '*':
        val = a * b;
        break;
      case '/':
        if (b == 0) return AiResult.reject('División por cero.');
        val = a / b;
        break;
      default:
        return AiResult.reject('Operación no soportada.');
    }
    if (val < 0) return AiResult.reject('El valor no puede ser negativo.');
    return AiResult.accept(val,
        hint:
        'Se calculó ${m.group(1)}$op${m.group(3)} → ${val.toStringAsFixed(3)}');
  }
}

/// Funciones estadísticas para Ω: sum/avg/max/min/median (opc. últimas N filas).
class OhmsStatsHandler extends RuleHandler {
  OhmsStatsHandler(this.config);
  final RuleConfig config;

  @override
  Future<AiResult?> process(AiCellContext ctx, String raw) async {
    if (ctx.columnName != MeasurementColumn.ohm1m &&
        ctx.columnName != MeasurementColumn.ohm3m) return null;

    final s = raw.trim().toLowerCase();
    String? fn;
    int? n;

    var m = _AiUtil.statsNoArg.firstMatch(s);
    if (m != null) {
      fn = m.group(1);
    } else {
      m = _AiUtil.statsWithArg.firstMatch(s);
      if (m != null) {
        fn = m.group(1);
        n = int.tryParse(m.group(2)!);
      }
    }
    if (fn == null) return null;

    Iterable<double> values;
    if (n != null && n > 0) {
      final start = (ctx.rowIndex - n + 1).clamp(0, ctx.rowIndex);
      values = ctx.rows
          .sublist(start, ctx.rowIndex + 1)
          .map((r) =>
      ctx.columnName == MeasurementColumn.ohm1m ? r.ohm1m : r.ohm3m);
    } else {
      values = _AiUtil.columnOhms(ctx);
    }

    final list = values
        .where((v) => v == v) // no NaN
        .where((v) => !config.statsIgnoreZeros || v != 0.0)
        .toList();

    double out;
    switch (fn) {
      case 'sum':
        out = list.isEmpty ? 0.0 : list.reduce((a, b) => a + b);
        break;
      case 'avg':
        out = list.isEmpty ? 0.0 : list.reduce((a, b) => a + b) / list.length;
        break;
      case 'max':
        out = list.isEmpty ? 0.0 : list.reduce((a, b) => a > b ? a : b);
        break;
      case 'min':
        out = list.isEmpty ? 0.0 : list.reduce((a, b) => a < b ? a : b);
        break;
      case 'median':
        out = _AiUtil.median(List<double>.from(list));
        break;
      default:
        return AiResult.reject('Función no soportada.');
    }

    final suf = (n != null) ? ' (últimas $n filas)' : '';
    return AiResult.accept(out,
        hint: '${fn.toUpperCase()}$suf = ${out.toStringAsFixed(3)}');
  }
}

/// Número directo con sufijo k/m en Ω.
class OhmsDirectNumberHandler extends RuleHandler {
  @override
  Future<AiResult?> process(AiCellContext ctx, String raw) async {
    if (ctx.columnName != MeasurementColumn.ohm1m &&
        ctx.columnName != MeasurementColumn.ohm3m) return null;

    final s = raw.toLowerCase().replaceAll(' ', '');
    if (!_AiUtil.numWithUnitRegex.hasMatch(s)) return null;

    final v = _AiUtil.parseWithUnit(raw);
    if (v == null) {
      return AiResult.reject('Valor no numérico.', hint: 'Ej: 12.5, 3k');
    }
    if (v < 0) return AiResult.reject('El valor no puede ser negativo.');
    return AiResult.accept(v);
  }
}

/// Macros de observaciones (#ok, #fallo, #gps, #dup…)
class ObservationMacroHandler extends RuleHandler {
  ObservationMacroHandler(this.config);
  final RuleConfig config;

  @override
  Future<AiResult?> process(AiCellContext ctx, String raw) async {
    if (ctx.columnName != MeasurementColumn.observations) return null;
    if (!raw.startsWith('#')) return null;

    final macro = config.observationMacros[raw];
    if (macro == null) return AiResult.reject('Macro desconocida.');
    if (macro == '<gps>') {
      final gps = _AiUtil.gpsText(ctx) ?? 'Sin coordenadas disponibles.';
      return AiResult.accept(gps, hint: 'Macro aplicada: #gps');
    }
    return AiResult.accept(macro, hint: 'Macro aplicada: $raw');
  }
}

/// Expansiones cortas en Observaciones.
class ObservationExpandHandler extends RuleHandler {
  @override
  Future<AiResult?> process(AiCellContext ctx, String raw) async {
    if (ctx.columnName != MeasurementColumn.observations) return null;
    if (raw.trim().isEmpty) return AiResult.accept('');

    final out = raw
        .replaceAll(' s/n ', ' sin novedad ')
        .replaceAll(' c/ruido ', ' con ruido ')
        .trim();

    if (out == raw) return null;
    return AiResult.accept(out);
  }
}

/// Palabras clave de fecha.
class DateKeywordHandler extends RuleHandler {
  @override
  Future<AiResult?> process(AiCellContext ctx, String raw) async {
    if (ctx.columnName != MeasurementColumn.date) return null;
    final s = raw.toLowerCase().trim();

    if (s == 'hoy' || s == 'today') {
      final d = ctx.now;
      return AiResult.accept(DateTime.utc(d.year, d.month, d.day));
    }
    if (s == 'ayer' || s == 'yesterday') {
      final y = ctx.now.subtract(const Duration(days: 1));
      return AiResult.accept(DateTime.utc(y.year, y.month, y.day));
    }
    if (s == 'mañana' || s == 'tomorrow') {
      final t = ctx.now.add(const Duration(days: 1));
      return AiResult.accept(DateTime.utc(t.year, t.month, t.day));
    }
    return null;
  }
}

/// Desplazamientos relativos: +N / -N días.
class DateRelativeHandler extends RuleHandler {
  @override
  Future<AiResult?> process(AiCellContext ctx, String raw) async {
    if (ctx.columnName != MeasurementColumn.date) return null;
    final s = raw.trim();
    if (!_AiUtil.relDaysRegex.hasMatch(s)) return null;

    final delta = int.tryParse(s) ?? 0;
    final base =
    (ctx.oldValue is DateTime ? (ctx.oldValue as DateTime) : ctx.now)
        .toUtc();
    final dt = base.add(Duration(days: delta));
    return AiResult.accept(
      DateTime.utc(dt.year, dt.month, dt.day),
      hint: 'Fecha desplazada $delta día(s).',
    );
  }
}

/// Parse dd/mm/yyyy (o dd-mm-yyyy) con validación real de calendario.
class DateParseHandler extends RuleHandler {
  @override
  Future<AiResult?> process(AiCellContext ctx, String raw) async {
    if (ctx.columnName != MeasurementColumn.date) return null;
    final m = _AiUtil.dateRegex.firstMatch(raw.trim());
    if (m == null) return null;

    final d = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    var y = int.parse(m.group(3)!);
    if (y < 100) y += 2000;

    final dt = _AiUtil.safeDateUtc(y, mo, d);
    if (dt == null) {
      return AiResult.reject('Fecha inválida (ej: 31/04 no existe).');
    }
    return AiResult.accept(dt);
  }
}

/// ───────────────────── Asistente compuesto (reglas) ───────────────────────────
class RuleBasedAssistant implements GridnoteAssistant {
  RuleBasedAssistant({RuleConfig? config}) : config = config ?? const RuleConfig() {
    final chain = <RuleHandler>[
      CopyPreviousHandler(),
      AutoProgresivaHandler(this.config),
      OhmsArithmeticHandler(),
      OhmsStatsHandler(this.config),
      OhmsDirectNumberHandler(),
      ObservationMacroHandler(this.config),
      ObservationExpandHandler(),
      DateKeywordHandler(),
      DateRelativeHandler(),
      DateParseHandler(),
    ];
    for (var i = 0; i < chain.length - 1; i++) {
      chain[i].setNext(chain[i + 1]);
    }
    _root = chain.first;
  }

  final RuleConfig config;
  late final RuleHandler _root;

  @override
  Future<AiResult> transform(AiCellContext ctx) async {
    final raw = (ctx.rawInput ?? '').toString().trim();
    final r = await _root.tryHandle(ctx, raw);
    return r ?? AiResult.accept(raw);
  }
}
