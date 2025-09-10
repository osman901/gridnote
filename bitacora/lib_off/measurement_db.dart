// lib/services/measurement_db.dart
//
// Almacenamiento 100% local con Hive (sin SQLite).
// Usa la key autoincremental de Hive; el modelo Measurement NO necesita `id`.

import 'package:hive_flutter/hive_flutter.dart';
import '../models/measurement.dart';

const _kBoxName = 'measurements_box_v2';

class MeasurementDB {
  MeasurementDB._();
  static final MeasurementDB instance = MeasurementDB._();

  Box? _box;

  Future<Box> _ensureBox() async {
    // Asegurate de llamar a Hive.initFlutter() en main() antes de usar esto.
    if (_box != null && _box!.isOpen) return _box!;
    if (!Hive.isBoxOpen(_kBoxName)) {
      _box = await Hive.openBox(_kBoxName);
    } else {
      _box = Hive.box(_kBoxName);
    }
    return _box!;
  }

  /// Inserta y devuelve la key autogenerada.
  Future<int> insert(Measurement m) async {
    final box = await _ensureBox();
    final map = Map<String, dynamic>.from(m.toJson());
    final key = await box.add(map); // key int autoincremental
    return key;
  }

  /// Devuelve todas las mediciones, ordenadas por key ascendente.
  Future<List<Measurement>> getAll() async {
    final box = await _ensureBox();

    // Recorremos como entries para poder ordenar por key (int).
    final entries = box.toMap().entries
        .where((e) => e.value is Map)
        .cast<MapEntry<dynamic, Map>>() // value es Map
        .toList();

    // Orden por key (siempre int en este box).
    entries.sort((a, b) {
      final ai = (a.key is int) ? a.key as int : 0;
      final bi = (b.key is int) ? b.key as int : 0;
      return ai.compareTo(bi);
    });

    return entries
        .map((e) => Measurement.fromJson(Map<String, dynamic>.from(e.value)))
        .toList(growable: false);
  }

  /// Actualiza el registro en la key indicada.
  Future<void> updateAt(int key, Measurement m) async {
    final box = await _ensureBox();
    final map = Map<String, dynamic>.from(m.toJson());
    await box.put(key, map);
  }

  /// Elimina el registro por key.
  Future<void> deleteKey(int key) async {
    final box = await _ensureBox();
    await box.delete(key);
  }

  /// Limpia el box completo.
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
