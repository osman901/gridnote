// lib/services/measurement_db.dart
//
// Reemplazo sin SQLite: almacenamiento 100% local con Hive.
// No requiere sqflite ni sqflite_common_ffi.

import 'package:hive_flutter/hive_flutter.dart';
import '../models/measurement.dart';

const _kBoxName = 'measurements_box_v2';

class MeasurementDB {
  MeasurementDB._();
  static final MeasurementDB instance = MeasurementDB._();

  Box? _box;

  Future<Box> _ensureBox() async {
    // Asume que Hive.initFlutter() se hace en main.dart.
    if (_box != null && _box!.isOpen) return _box!;
    if (!Hive.isBoxOpen(_kBoxName)) {
      _box = await Hive.openBox(_kBoxName);
    } else {
      _box = Hive.box(_kBoxName);
    }
    return _box!;
  }

  Future<int> insert(Measurement m) async {
    final box = await _ensureBox();
    // Guardamos como Map (sin adapters).
    final map = Map<String, dynamic>.from(m.toJson());
    // 1) add -> devuelve key autoincremental
    final key = await box.add(map);
    // 2) actualizar el registro con el id persistido
    map['id'] = key;
    await box.put(key, map);
    return key;
  }

  Future<List<Measurement>> getAll() async {
    final box = await _ensureBox();
    final values = box.values;
    final list = <Measurement>[];
    for (final v in values) {
      if (v is Map) {
        final map = Map<String, dynamic>.from(v);
        // Hive guarda DateTime nativamente; Measurement.fromJson acepta DateTime.
        list.add(Measurement.fromJson(map));
      }
    }
    // Orden por id ascendente (si existe)
    list.sort((a, b) {
      final ai = a.id ?? -1;
      final bi = b.id ?? -1;
      return ai.compareTo(bi);
    });
    return list;
  }

  Future<int> update(Measurement m) async {
    if (m.id == null) {
      // Si no hay id, hacemos insert.
      return insert(m);
    }
    final box = await _ensureBox();
    final map = Map<String, dynamic>.from(m.toJson())..['id'] = m.id;
    await box.put(m.id, map);
    return m.id!;
  }

  Future<int> delete(int id) async {
    final box = await _ensureBox();
    await box.delete(id);
    return 1;
  }

  Future<void> clear() async {
    final box = await _ensureBox();
    await box.clear();
  }

  Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
      _box = null;
    }
  }
}
