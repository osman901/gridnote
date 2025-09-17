// lib/repositories/measurement_repository.dart
import '../models/measurement.dart';

/// Contrato para repositorios de mediciones (persistencia/lectura).
abstract class MeasurementRepository {
  Future<List<Measurement>> fetchAll();
  Future<void> saveAll(List<Measurement> items);
  Future<Measurement> add(Measurement item);
  Future<Measurement> update(Measurement item);
  Future<void> delete(Measurement item);
}
