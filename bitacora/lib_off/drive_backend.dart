// lib/services/drive_backend.dart
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/measurement.dart';
import 'storage_backend.dart';
import 'xlsx_export_service.dart';

/// Stub local que emula un "Drive" sin dependencias externas.
/// Guarda un JSON y subidas bajo <Documents>/gridnote_drive_stub/
class DriveBackend implements StorageBackend {
  DriveBackend({
    this.folderName = 'Gridnote',
    this.dataFileName = 'gridnote_data.json',
  });

  final String folderName;
  final String dataFileName;

  @override
  String get name => 'Drive (modo local)';

  Directory? _base;

  Future<Directory> _baseDir() async {
    if (_base != null) return _base!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'gridnote_drive_stub', folderName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _base = dir;
    return dir;
  }

  File _jsonFileIn(Directory dir) => File(p.join(dir.path, dataFileName));

  @override
  Future<void> init() async {
    // No-op en stub local.
    await _baseDir();
  }

  @override
  Future<List<Measurement>> loadAll() async {
    final dir = await _baseDir();
    final f = _jsonFileIn(dir);
    if (!await f.exists()) return <Measurement>[];
    try {
      final txt = await f.readAsString();
      final map = jsonDecode(txt) as Map<String, dynamic>;
      final list = (map['items'] as List? ?? const <dynamic>[])
          .cast<Map<String, dynamic>>();
      return list.map(Measurement.fromJson).toList(growable: false);
    } catch (_) {
      // Si el archivo estÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ corrupto, empieza vacÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­o.
      return <Measurement>[];
    }
  }

  @override
  Future<void> saveAll(List<Measurement> items) async {
    final dir = await _baseDir();
    final f = _jsonFileIn(dir);
    final content = jsonEncode({
      'version': 1,
      'updatedAt': DateTime.now().toIso8601String(),
      'items': items.map((e) => e.toJson()).toList(),
    });
    await f.writeAsString(content, flush: true);
  }

  @override
  Future<File> exportXlsx({
    required String fileName,
    List<String>? headers,
  }) async {
    // Exporta desde el contenido actual guardado.
    final data = await loadAll();

    // Quitar .xlsx si viene incluido (el servicio agrega la extensiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n).
    var title = fileName.trim();
    if (title.toLowerCase().endsWith('.xlsx')) {
      title = title.substring(0, title.length - 5);
    }

    final svc = XlsxExportService();
    return svc.buildFile(
      sheetId: 'drive_stub',
      title: title,
      data: data,
      headers: headers,
    );
  }

  /// "Sube" un archivo copiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ndolo a /uploads y devuelve una URL file://
  @override
  Future<String?> uploadFile(File file) async {
    final dir = await _baseDir();
    final uploads = Directory(p.join(dir.path, 'uploads'));
    if (!await uploads.exists()) {
      await uploads.create(recursive: true);
    }
    final target = File(p.join(uploads.path, p.basename(file.path)));
    await file.copy(target.path);
    return Uri.file(target.path).toString();
  }
}
