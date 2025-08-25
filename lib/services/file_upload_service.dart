// lib/services/file_upload_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Stub local que reemplaza a Firebase Storage.
/// Guarda archivos bajo <Documents>/uploads/<folder>/ y devuelve una URL file://
class FileUploadService {
  const FileUploadService();

  /// Guarda [bytes] como archivo local y devuelve una URL file://
  Future<String> uploadReportBytes({
    required Uint8List bytes,
    required String filename,
    String? contentType, // ignorado en stub local
  }) async {
    final objectPath = _objectPath('reports', filename);
    final file = await _writeBytes(objectPath, bytes);
    return Uri.file(file.path).toString();
  }

  /// Copia un archivo local a la carpeta de uploads y devuelve una URL file://
  Future<String> uploadReportFile({
    required File file,
    String folder = 'reports',
  }) async {
    final objectPath = _objectPath(folder, p.basename(file.path));
    final target = await _destFile(objectPath);
    await target.parent.create(recursive: true);
    await file.copy(target.path);
    return Uri.file(target.path).toString();
  }

  /// Elimina por ruta de objeto (relativa o absoluta).
  Future<void> deleteByPath(String objectPath) async {
    final file = await _fileFromObjectPath(objectPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Elimina a partir de una URL file://
  Future<void> deleteByDownloadUrl(String downloadUrl) async {
    final uri = Uri.parse(downloadUrl);
    if (uri.scheme != 'file') {
      throw ArgumentError('Solo se soportan URLs file:// en el stub local.');
    }
    final path = uri.toFilePath();
    final f = File(path);
    if (await f.exists()) {
      await f.delete();
    }
  }

  // ----------------- Helpers -----------------

  Future<Directory> _baseDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final base = Directory(p.join(docs.path, 'uploads'));
    if (!await base.exists()) await base.create(recursive: true);
    return base;
  }

  String _objectPath(String folder, String filename) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final safe = filename.replaceAll(RegExp(r'[^\w\-. ]+'), '_');
    return p.join(folder, '$ts-$safe');
  }

  Future<File> _destFile(String objectPath) async {
    final base = await _baseDir();
    return File(p.join(base.path, objectPath));
  }

  Future<File> _writeBytes(String objectPath, Uint8List bytes) async {
    final file = await _destFile(objectPath);
    await file.parent.create(recursive: true);
    return file.writeAsBytes(bytes, flush: true);
  }

  Future<File> _fileFromObjectPath(String objectPath) async {
    // Si viene absoluta, úsala; si no, la resolvemos bajo /uploads
    final f = File(objectPath);
    if (p.isAbsolute(objectPath)) return f;
    final base = await _baseDir();
    return File(p.join(base.path, objectPath));
  }
}
