// lib/services/ai_service.dart
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiService {
  AiService._();
  static final AiService instance = AiService._();

  static const _boxName = 'ai_stats';
  Box<dynamic>? _box;

  /// Inicializa sin exigir .env ni claves externas.
  Future<void> init() async {
    try {
      _box = await Hive.openBox<dynamic>(_boxName);

      // Lee vars si existen, pero sin fallar si no hay .env
      if (dotenv.isInitialized) {
        final flag = dotenv.maybeGet('AI_ENABLED');
        debugPrint('AiService.init OK (AI_ENABLED=$flag)');
      } else {
        debugPrint('AiService.init OK (dotenv no inicializado)');
      }
    } catch (e, st) {
      debugPrint('AiService.init error: $e\n$st');
    }
  }

  /// Respuesta silenciosa para no ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œmanifestarÃƒÂ¢Ã¢â€šÂ¬Ã‚Â la IA en UI.
  /// MantÃƒÆ’Ã‚Â©n este mÃƒÆ’Ã‚Â©todo para compatibilidad con Home.
  Future<String> ask(String prompt) async {
    debugPrint('AiService.ask (silencioso): $prompt');
    return 'ok';
  }

  /// Aprende estadÃƒÆ’Ã‚Â­sticas bÃƒÆ’Ã‚Â¡sicas de filas numÃƒÆ’Ã‚Â©ricas (n, sum, min, max, sumSq).
  /// `rows` es una lista de filas; cada fila es una lista de celdas.
  Future<void> learnFromRows(List<List<dynamic>> rows) async {
    final b = _box;
    if (b == null || rows.isEmpty) return;

    final global = Map<String, dynamic>.from(b.get('global') ?? const {});
    global['count'] = (global['count'] as int? ?? 0) + rows.length;

    final cols = Map<String, dynamic>.from(b.get('cols') ?? const {});

    for (final row in rows) {
      for (var i = 0; i < row.length; i++) {
        final v = row[i];
        if (v is num) {
          final key = i.toString();
          final m = Map<String, dynamic>.from(cols[key] ?? const {});
          final n0 = (m['n'] as int?) ?? 0;
          final sum0 = (m['sum'] as num?)?.toDouble() ?? 0.0;
          final min0 = (m['min'] as num?)?.toDouble() ?? double.infinity;
          final max0 = (m['max'] as num?)?.toDouble() ?? -double.infinity;
          final sumSq0 = (m['sumSq'] as num?)?.toDouble() ?? 0.0;

          final x = v.toDouble();
          m['n'] = n0 + 1;
          m['sum'] = sum0 + x;
          m['min'] = math.min(min0, x);
          m['max'] = math.max(max0, x);
          m['sumSq'] = sumSq0 + x * x;

          cols[key] = m;
        }
      }
    }

    await b.put('global', global);
    await b.put('cols', cols);
  }

  /// Solo para inspecciÃƒÆ’Ã‚Â³n en debug.
  Map<String, dynamic> get debugSnapshot {
    final b = _box;
    if (b == null) return const {};
    return {
      'global': b.get('global'),
      'cols': b.get('cols'),
    };
  }
}
