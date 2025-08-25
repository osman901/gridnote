// test/fakes/fake_repository.dart
import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../lib/state/measurement_repository.dart';
import '../../lib/models/measurement.dart';

class FakeDelayRepo implements MeasurementRepository {
  final List<Measurement> _store;
  final Duration delay;
  final _uuid = const Uuid();

  FakeDelayRepo({List<Measurement>? seed, this.delay = const Duration(milliseconds: 150)})
      : _store = List.of(seed ?? const []);

  @override
  Future<List<Measurement>> fetchAll() async {
    await Future.delayed(delay);
    return List<Measurement>.from(_store);
  }

  @override
  Future<Measurement> add(Measurement item) async {
    await Future.delayed(delay);
    final id = item.id ?? int.tryParse(_uuid.v4().hashCode.toString().replaceAll('-', '').substring(0, 6));
    final saved = item.copyWith(id: id);
    _store.add(saved);
    return saved;
  }

  @override
  Future<void> delete(Measurement item) async {
    await Future.delayed(delay);
    _store.removeWhere((e) => e.id == item.id);
  }

  @override
  Future<void> saveMany(List<Measurement> items) async {
    await Future.delayed(delay);
    _store
      ..clear()
      ..addAll(items.mapIndexed((i, m) => m.id == null ? m.copyWith(id: i + 1) : m));
  }

  @override
  Future<Measurement> update(Measurement item) async {
    await Future.delayed(delay);
    final idx = _store.indexWhere((e) => e.id == item.id);
    if (idx == -1) throw StateError('not found');
    _store[idx] = item;
    return item;
  }
}
