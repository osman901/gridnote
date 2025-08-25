// lib/repositories/local_measurement_repository.dart
import '../models/measurement.dart';
import '../services/storage_manager.dart';
import '../state/measurement_repository.dart';

/// Repositorio local (por planilla) que persiste con StorageManager.
class LocalMeasurementRepository implements MeasurementRepository {
  LocalMeasurementRepository(this.sheetId);
  final String sheetId;

  @override
  Future<List<Measurement>> fetchAll() =>
      StorageManager.instance.loadAll(sheetId);

  @override
  Future<Measurement> add(Measurement item) async {
    final all = await fetchAll();
    final nextId = (all.isEmpty
        ? 0
        : all.map((e) => e.id ?? 0).reduce((a, b) => a > b ? a : b)) +
        1;
    final saved = item.copyWith(id: nextId);
    final next = List<Measurement>.from(all)..add(saved);
    await StorageManager.instance.saveAll(sheetId, next);
    return saved;
  }

  @override
  Future<Measurement> update(Measurement item) async {
    final all = await fetchAll();
    final i = all.indexWhere((e) => e.id == item.id);
    if (i >= 0) {
      all[i] = item;
      await StorageManager.instance.saveAll(sheetId, all);
    }
    return item;
  }

  @override
  Future<void> delete(Measurement item) async {
    final all = await fetchAll();
    all.removeWhere((e) => e.id == item.id);
    await StorageManager.instance.saveAll(sheetId, all);
  }

  /// Requerido por la interfaz.
  @override
  Future<void> saveAll(List<Measurement> items) =>
      StorageManager.instance.saveAll(sheetId, items);

  /// Compatibilidad con llamadores que usen `saveMany`.
  @override
  Future<void> saveMany(List<Measurement> items) => saveAll(items);
}
