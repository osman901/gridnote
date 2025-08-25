// lib/repositories/measurement_hive_repository.dart
import 'dart:math';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/measurement.dart';
import '../state/measurement_repository.dart';

const _kBoxName = 'measurements_box';
const _kTypeIdMeasurement = 17; // Único en tu app

class MeasurementHiveRepository implements MeasurementRepository {
  MeasurementHiveRepository._(this._box);
  final Box<Measurement> _box;

  /// Llamá esto una sola vez (Hive ya debe estar inicializado en main.dart)
  static Future<MeasurementHiveRepository> init() async {
    if (!Hive.isAdapterRegistered(_kTypeIdMeasurement)) {
      Hive.registerAdapter(_MeasurementHiveAdapter());
    }
    final box = await Hive.openBox<Measurement>(_kBoxName);
    return MeasurementHiveRepository._(box);
  }

  @override
  Future<List<Measurement>> fetchAll() async {
    return _box.values.toList(growable: false);
  }

  /// Compat: algunos llamadores usan `saveMany`.
  @override
  Future<void> saveMany(List<Measurement> items) => saveAll(items);

  @override
  Future<void> saveAll(List<Measurement> items) async {
    await _box.clear();

    // Asignamos IDs consistentes (si falta alguno)
    int nextId = 0;
    final map = <int, Measurement>{};
    for (final m in items) {
      final id = m.id ?? nextId++;
      nextId = max(nextId, id + 1);
      map[id] = m.copyWith(id: id);
    }
    await _box.putAll(map);
  }

  @override
  Future<Measurement> add(Measurement item) async {
    final key = await _box.add(item);        // add devuelve int
    final withId = item.copyWith(id: key);   // aseguramos id
    await _box.put(key, withId);
    return withId;
  }

  @override
  Future<Measurement> update(Measurement item) async {
    if (item.id == null) return add(item);
    await _box.put(item.id, item);
    return item;
  }

  @override
  Future<void> delete(Measurement item) async {
    final id = item.id;
    if (id == null) return;
    if (_box.containsKey(id)) {
      await _box.delete(id);
    }
  }
}

/* ------------ Hive Adapter manual para Measurement ------------ */
class _MeasurementHiveAdapter extends TypeAdapter<Measurement> {
  @override
  final int typeId = _kTypeIdMeasurement;

  @override
  Measurement read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return Measurement(
      id: fields[0] as int?,
      progresiva: fields[1] as String? ?? '',
      ohm1m: (fields[2] as num?)?.toDouble() ?? 0.0,
      ohm3m: (fields[3] as num?)?.toDouble() ?? 0.0,
      observations: fields[4] as String? ?? '',
      date: fields[5] as DateTime? ?? DateTime.now(),
      latitude: (fields[6] as num?)?.toDouble(),
      longitude: (fields[7] as num?)?.toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, Measurement obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.progresiva)
      ..writeByte(2)
      ..write(obj.ohm1m)
      ..writeByte(3)
      ..write(obj.ohm3m)
      ..writeByte(4)
      ..write(obj.observations)
      ..writeByte(5)
      ..write(obj.date)
      ..writeByte(6)
      ..write(obj.latitude)
      ..writeByte(7)
      ..write(obj.longitude);
  }
}
