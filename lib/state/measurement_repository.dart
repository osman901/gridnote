import '../models/measurement.dart';

/// Contrato de repositorio para una planilla.
abstract class MeasurementRepository {
  Future<List<Measurement>> fetchAll();
  Future<Measurement> add(Measurement item);
  Future<Measurement> update(Measurement item);
  Future<void> delete(Measurement item);

  /// Preferido por el stack de comandos.
  Future<void> saveMany(List<Measurement> items);

  /// Compatibilidad con código viejo: NO es abstracta.
  @Deprecated('Usá saveMany(List<Measurement>)')
  Future<void> saveAll(List<Measurement> items) async {
    await saveMany(items);
  }
}
