// test/fakes/fake_repository.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:gridnote/state/measurement_repository.dart';
import 'package:gridnote/models/measurement.dart';

class FakeDelayRepo implements MeasurementRepository {
  final List<Measurement> _store;
  final Duration delay;
  final math.Random _rnd = math.Random();

  FakeDelayRepo({
    List<Measurement>? seed,
    this.delay = const Duration(milliseconds: 150),
  }) : _store = List.of(seed ?? const []);

  @override
  Future<List<Measurement>> fetchAll() async {
    await Future.delayed(delay);
    return List<Measurement>.from(_store);
  }

  @override
  Future<Measurement> add(Measurement item) async {
    await Future.delayed(delay);
    final id = item.id ?? _nextId();
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
  Future<void> saveAll(List<Measurement> items) async {
    await Future.delayed(delay);
    _store
      ..clear()
      ..addAll(
        items.mapIndexed((i, m) => m.id == null ? m.copyWith(id: i + 1) : m),
      );
  }

  // (opcional) Mantengo el alias si en algún test viejo llaman saveMany.
  @override
  Future<void> saveMany(List<Measurement> items) => saveAll(items);

  @override
  Future<Measurement> update(Measurement item) async {
    await Future.delayed(delay);
    final idx = _store.indexWhere((e) => e.id == item.id);
    if (idx == -1) throw StateError('not found');
    _store[idx] = item;
    return item;
  }

  int _nextId() {
    var id = _rnd.nextInt(900000) + 100000; // 6 dígitos
    while (_store.any((e) => e.id == id)) {
      id = _rnd.nextInt(900000) + 100000;
    }
    return id;
  }
}
