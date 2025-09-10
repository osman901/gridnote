import '../models/measurement.dart';
import 'measurement_storage.dart';
import 'local_measurement_repository.dart';

/// Placeholder de repo **cifrado**: por ahora delega al JSON local.
/// Más adelante podés reemplazar la lógica interna por IO cifrado.
class EncryptedLocalMeasurementRepository extends LocalMeasurementRepository
    implements MeasurementStorage {
  EncryptedLocalMeasurementRepository(String sheetId) : super(sheetId);
}
