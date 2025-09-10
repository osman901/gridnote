// lib/services/storage_manager.dart
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/measurement.dart';

/// Almacenamiento local por planilla (JSON).
/// - Estructura: {appDocs}/data/{sheetIdSanitizado}/measurements.json
/// - Escritura atómica (tmp -> rename) + backup opcional .bak
/// - Sin dependencia de BuildContext.
class StorageManager {
  StorageManager._();
  static final StorageManager instance = StorageManager._();

  Future<Directory> _baseDir() async {
    final app = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(app.path, 'data'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> _sheetDir(String sheetId) async {
    final base = await _baseDir();
    final safe = sheetId.replaceAll(RegExp(r'[^\w\-]+'), '_');
    final dir = Directory(p.join(base.path, safe));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _dataFile(String sheetId) async {
    final dir = await _sheetDir(sheetId);
    return File(p.join(dir.path, 'measurements.json'));
  }

  /// Devuelve la ruta de la carpeta de una planilla.
  Future<String> sheetDirPath(String sheetId) async =>
      (await _sheetDir(sheetId)).path;

  /// Devuelve la ruta del archivo JSON de una planilla (no garantiza existencia).
  Future<String> dataFilePath(String sheetId) async =>
      (await _dataFile(sheetId)).path;

  /// Crea el archivo JSON de la planilla si no existe y devuelve su ruta.
  Future<String> ensureSheetFile(String sheetId) async {
    final f = await _dataFile(sheetId);
    if (!await f.exists()) {
      // Crear archivo vacío consistente
      await saveAll(sheetId, const <Measurement>[]);
    }
    return f.path;
  }

  /// Carga todas las mediciones de una planilla.
  Future<List<Measurement>> loadAll(String sheetId) async {
    try {
      final f = await _dataFile(sheetId);
      if (!await f.exists()) return <Measurement>[];
      final txt = await f.readAsString();
      if (txt.trim().isEmpty) return <Measurement>[];
      final raw = json.decode(txt);
      if (raw is! List) return <Measurement>[];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(Measurement.fromJson)
          .toList(growable: false);
    } catch (_) {
      // En caso de archivo corrupto o error de parseo, devolvemos lista vacía.
      return <Measurement>[];
    }
  }

  /// Guarda todas las mediciones de una planilla.
  /// Escribe a archivo temporal y reemplaza para evitar corrupción.
  Future<void> saveAll(String sheetId, List<Measurement> items) async {
    final f = await _dataFile(sheetId);
    final tmp = File('${f.path}.tmp');

    final list = items.map((m) => m.toJson()).toList(growable: false);
    final payload = const JsonEncoder.withIndent('  ').convert(list);

    // Escribir temporal
    await tmp.writeAsString(payload, flush: true);

    // Reemplazo lo más atómico posible
    if (await f.exists()) {
      try {
        await f.delete();
      } catch (_) {
        // Si no se puede borrar, intentaremos renombrar igual abajo
      }
    }
    await tmp.rename(f.path);

    // Backup opcional simple (best-effort)
    try {
      final bak = File('${f.path}.bak');
      await bak.writeAsString(payload, flush: false);
    } catch (_) {
      // Ignorar fallos de backup
    }
  }
}
