import '../models/measurement.dart';

/// Interfaz de **almacenamiento** (sin estado de UI).
/// Cualquier backend (JSON local, Hive, REST, cifrado, memoria) implementa esto.
abstract class MeasurementStorage {
  /// Lee **toda** la planilla.
  Future<List<Measurement>> fetchAll();

  /// Guarda **toda** la planilla (reemplazo completo).
  Future<void> saveAll(List<Measurement> items);

  /// Alta de una fila. Debe devolver la fila con `id` asignado (si aplica).
  Future<Measurement> add(Measurement item);

  /// Modificación. Si no existe, puede optar por crearlo.
  Future<Measurement> update(Measurement item);

  /// Borrado por `id` (si `id` es null, se ignora).
  Future<void> delete(Measurement item);

  /// Alias opcional usado por algunos providers.
  Future<void> saveMany(List<Measurement> items) => saveAll(items);
}
