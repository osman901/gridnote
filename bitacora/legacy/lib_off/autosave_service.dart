// lib/services/autosave_service.dart
//
// Autosave simple y defensivo para listas de Measurement.
// - Guarda/lee un archivo JSON *sin cifrar* separado del principal.
// - Se usa como ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã¢â‚¬Å“red de seguridadÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â si el archivo encriptado principal falla.
// - API minimalista para lo que requiere EncryptedLocalMeasurementRepository.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/measurement.dart';

class AutosaveService {
  AutosaveService._();

  static const _folder = 'autosave';
  static const _ext = '.jsonc.autosave';

  static Future<File> _fileFor(String sheetId) async {
    final dir = await getApplicationDocumentsDirectory();
    final base = Directory(p.join(dir.path, _folder));
    if (!await base.exists()) {
      await base.create(recursive: true);
    }
    return File(p.join(base.path, '$sheetId$_ext'));
  }

  /// Devuelve la fecha de modificaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n del autosave o `null` si no existe.
  static Future<DateTime?> mtime(String sheetId) async {
    try {
      final f = await _fileFor(sheetId);
      if (await f.exists()) {
        return f.lastModified();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Intenta leer y parsear el autosave. Si algo falla, devuelve `null`.
  static Future<List<Measurement>?> tryRead(String sheetId) async {
    try {
      final f = await _fileFor(sheetId);
      if (!await f.exists()) return null;
      final raw = await f.readAsString();
      final jsonData = jsonDecode(raw);
      if (jsonData is! List) return const <Measurement>[];
      return jsonData
          .map<Measurement>((e) => Measurement.fromJson(
        Map<String, dynamic>.from(e as Map),
      ))
          .toList(growable: false);
    } catch (_) {
      return null;
    }
  }

  /// Guarda un snapshot como autosave (texto JSON sin cifrar).
  static Future<void> write(String sheetId, List<Measurement> items) async {
    try {
      final f = await _fileFor(sheetId);
      final data = items.map((e) => e.toJson()).toList(growable: false);
      await f.writeAsString(jsonEncode(data), flush: true);
    } catch (_) {
      // Silencioso: el autosave nunca debe romper el flujo principal.
    }
  }

  /// Elimina el autosave del `sheetId` si existe.
  static Future<void> clear(String sheetId) async {
    try {
      final f = await _fileFor(sheetId);
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {
      // Silencioso.
    }
  }
}

