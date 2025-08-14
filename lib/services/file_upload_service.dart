// lib/services/file_upload_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart' as fs;
import 'package:path/path.dart' as p;

class FileUploadService {
  final fs.FirebaseStorage _storage;

  FileUploadService({fs.FirebaseStorage? storage})
      : _storage = storage ?? fs.FirebaseStorage.instance;

  /// Sube bytes al bucket en la carpeta "reports/" y devuelve la URL de descarga.
  /// [filename] se saneará y se le antepone un timestamp para evitar colisiones.
  Future<String> uploadReportBytes({
    required Uint8List bytes,
    required String filename,
    String? contentType,
  }) async {
    final objectPath = _objectPath('reports', filename);
    final ref = _storage.ref(objectPath);

    final meta = fs.SettableMetadata(
      contentType: contentType ?? _mimeFor(filename),
      cacheControl: 'public, max-age=3600',
    );

    // putData devuelve UploadTask; al await obtenemos TaskSnapshot
    final snap = await ref.putData(bytes, meta);
    final url = await snap.ref.getDownloadURL();
    return url;
  }

  /// Versión para archivos locales (Android/iOS/desktop).
  Future<String> uploadReportFile({
    required File file,
    String folder = 'reports',
  }) async {
    final filename = p.basename(file.path);
    final objectPath = _objectPath(folder, filename);
    final ref = _storage.ref(objectPath);

    final meta = fs.SettableMetadata(
      contentType: _mimeFor(filename),
      cacheControl: 'public, max-age=3600',
    );

    final snap = await ref.putFile(file, meta);
    final url = await snap.ref.getDownloadURL();
    return url;
  }

  /// Elimina un objeto por su path dentro del bucket (ej: 'reports/1234-file.xlsx').
  Future<void> deleteByPath(String objectPath) async {
    await _storage.ref(objectPath).delete();
  }

  /// Si tenés una URL pública de descarga, intenta derivar el path del objeto.
  /// (Funciona con URLs de Firebase Storage estándar.)
  Future<void> deleteByDownloadUrl(String downloadUrl) async {
    final uri = Uri.parse(downloadUrl);
    final segments = uri.pathSegments;
    // Busca el segmento después de 'o', que es la ruta encodeada del objeto
    final idx = segments.indexOf('o');
    if (idx != -1 && idx + 1 < segments.length) {
      final encoded = segments[idx + 1];
      final objectPath = Uri.decodeFull(encoded);
      await deleteByPath(objectPath);
    } else {
      throw ArgumentError('URL de descarga no reconocida');
    }
  }

  // ----------------- Helpers -----------------

  String _objectPath(String folder, String filename) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final safeName = filename.replaceAll(RegExp(r'[^\w\-. ]+'), '_');
    return '$folder/$ts-$safeName';
    // Ej: reports/1712800000000-Planilla_1.xlsx
  }

  String _mimeFor(String filename) {
    switch (p.extension(filename).toLowerCase()) {
      case '.pdf':
        return 'application/pdf';
      case '.xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case '.csv':
        return 'text/csv';
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }
}
