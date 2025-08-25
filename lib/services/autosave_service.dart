import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../models/measurement.dart';
import 'secure_store.dart';

class AutosaveService {
  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/autosave');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static Future<File> _file(String sheetId) async {
    final d = await _dir();
    return File('${d.path}/$sheetId.jsonc.autosave');
  }

  /// Guarda un autosave cifrado (normaliza IDs null).
  static Future<void> write(String sheetId, List<Measurement> items) async {
    int nextId = 0;
    final normalized = <Measurement>[];
    for (final m in items) {
      final id = m.id ?? nextId++;
      if (id >= nextId) nextId = id + 1;
      normalized.add(m.copyWith(id: id));
    }
    final bytes = Uint8List.fromList(
      utf8.encode(jsonEncode(normalized.map((e) => e.toJson()).toList())),
    );
    final f = await _file(sheetId);
    await SecureStore.instance.writeEncryptedFile(f, bytes);
  }

  /// Lee el autosave (si existe) y lo convierte a lista.
  static Future<List<Measurement>?> tryRead(String sheetId) async {
    final f = await _file(sheetId);
    if (!await f.exists()) return null;
    try {
      final dec = await SecureStore.instance.readDecryptedFile(f);
      if (dec == null) return null;
      final raw = jsonDecode(utf8.decode(dec));
      if (raw is! List) return null;
      return raw
          .map<Measurement>((e) => Measurement.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      return null;
    }
  }

  /// Fecha de modificación del autosave (para comparar con el archivo principal).
  static Future<DateTime?> mtime(String sheetId) async {
    final f = await _file(sheetId);
    if (!await f.exists()) return null;
    return f.lastModified();
  }

  /// Elimina el autosave.
  static Future<void> clear(String sheetId) async {
    final f = await _file(sheetId);
    if (await f.exists()) {
      await f.delete();
    }
  }
}
