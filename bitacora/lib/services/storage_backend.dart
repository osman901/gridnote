import 'dart:io';
import '../models/measurement.dart';

/// Contrato comÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºn para cualquier backend de almacenamiento.
abstract class StorageBackend {
  /// Nombre visible para UI.
  String get name;

  /// InicializaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n (claves, sesiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n, etc.).
  Future<void> init();

  /// Lee todas las mediciones.
  Future<List<Measurement>> loadAll();

  /// Reemplaza todo el contenido.
  Future<void> saveAll(List<Measurement> items);

  /// Exporta XLSX real y devuelve el File local generado.
  Future<File> exportXlsx({
    required String fileName,
    List<String>? headers,
  });

  /// (Opcional) Sube un File al backend remoto y devuelve ID/URL.
  Future<String?> uploadFile(File file);
}
