import '../models/measurement.dart';
import 'measurement_storage.dart';

/// Almacenamiento en **memoria** (útil para tests o previews).
class MeasurementMemoryRepository implements MeasurementStorage {
  final _items = <Measurement>[];

  @override
  Future<List<Measurement>> fetchAll() async => List.of(_items);

  @override
  Future<void> saveAll(List<Measurement> items) async {
    _items
      ..clear()
      ..addAll(items);
  }

  @override
  Future<void> saveMany(List<Measurement> items) => saveAll(items);

  @override
  Future<Measurement> add(Measurement item) async {
    final nextId = (_items.map((e) => e.id ?? -1).fold<int>(
      -1,
          (a, b) => b > a ? b : a,
    )) +
        1;
    final withId = item.copyWith(id: nextId);
    _items.add(withId);
    return withId;
  }

  @override
  Future<Measurement> update(Measurement item) async {
    if (item.id == null) return add(item);
    final i = _items.indexWhere((e) => e.id == item.id);
    if (i == -1) {
      _items.add(item);
    } else {
      _items[i] = item;
    }
    return item;
  }

  @override
  Future<void> delete(Measurement item) async {
    if (item.id == null) return;
    _items.removeWhere((e) => e.id == item.id);
  }
}
