import 'dart:io';
import 'package:file_picker/file_picker.dart';

/// Servicio de ayuda para seleccionar archivos y directorios.
/// Encapsula file_picker y expone mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©todos para seleccionar archivos o carpetas.
class FilePickerService {
  const FilePickerService._();

  /// Extensiones permitidas por defecto (xlsx, csv, xls, imÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡genes, pdf).
  static const List<String> defaultExtensions = <String>[
    'xlsx', 'csv', 'xls', 'jpg', 'jpeg', 'png', 'pdf',
  ];

  /// Selecciona mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºltiples archivos.
  static Future<List<File>> pickMultiple({List<String>? allowedExtensions}) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: allowedExtensions != null ? FileType.custom : FileType.any,
      allowedExtensions: allowedExtensions ?? defaultExtensions,
      withData: false,
    );
    if (result == null) return <File>[];
    return result.files
        .where((f) => f.path != null)
        .map((f) => File(f.path!))
        .toList();
  }

  /// Selecciona un directorio. Devuelve null si se cancela.
  static Future<String?> pickDirectory() {
    return FilePicker.platform.getDirectoryPath();
  }
}
