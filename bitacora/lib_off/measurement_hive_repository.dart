import '../models/measurement.dart';
import 'measurement_storage.dart';
import 'local_measurement_repository.dart';

/// Placeholder Hive: compila y funciona delegando al JSON local.
/// Cuando implementes Hive, reemplazá la herencia y escribí la lógica real.
class MeasurementHiveRepository extends LocalMeasurementRepository
    implements MeasurementStorage {
  MeasurementHiveRepository(String sheetId) : super(sheetId);
}
