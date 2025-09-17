import '../models/measurement.dart';
import 'measurement_storage.dart';
import 'local_measurement_repository.dart';

/// Placeholder REST: delega al JSON local para no romper el build.
/// Cuando tengas el backend, cambiá esta clase por llamadas HTTP reales.
class MeasurementRestRepository extends LocalMeasurementRepository
    implements MeasurementStorage {
  MeasurementRestRepository(String sheetId) : super(sheetId);
}
