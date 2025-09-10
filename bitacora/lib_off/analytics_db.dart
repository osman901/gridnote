import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';

/// Almacen local de eventos de uso (ligero y offline-first).
/// Esquema simple: cada item es un Map { name, ts }.
class AnalyticsDB {
  static const _boxName = 'analytics_events_v1';
  static final AnalyticsDB instance = AnalyticsDB._();
  AnalyticsDB._();

  Box<Map>? _box;

  Future<void> open() async {
    if (_box?.isOpen == true) return;
    _box = await Hive.openBox<Map>(_boxName);
  }

  Future<void> add(String name) async {
    await open();
    await _box!.add({
      'name': name,
      'ts': DateTime.now().toUtc().millisecondsSinceEpoch,
    });
  }

  /// Devuelve conteos por evento en la ventana de tiempo dada (dÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­as).
  Future<Map<String, int>> counts({int days = 30}) async {
    await open();
    final since = DateTime.now().toUtc().subtract(Duration(days: days)).millisecondsSinceEpoch;
    final out = <String, int>{};
    for (final v in _box!.values) {
      final ts = (v['ts'] ?? 0) as int;
      if (ts >= since) {
        final n = (v['name'] ?? '') as String;
        if (n.isEmpty) continue;
        out[n] = (out[n] ?? 0) + 1;
      }
    }
    return out;
  }

  Future<void> clearAll() async {
    await open();
    await _box!.clear();
  }
}
