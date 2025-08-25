import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/measurement.dart';
import 'encryption_service.dart';

class StorageManager {
  StorageManager._();
  static final instance = StorageManager._();

  String get name => 'Local (encriptado)';

  Future<Directory> _baseDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final base = Directory(p.join(dir.path, 'gridnote', 'sheets'));
    if (!await base.exists()) await base.create(recursive: true);
    return base;
  }

  Future<String> sheetFilePath(String sheetId) async {
    final base = await _baseDir();
    return p.join(base.path, '$sheetId.enc');
  }

  /// Crea el archivo vacío encriptado si no existe y devuelve la ruta.
  Future<String> ensureSheetFile(String sheetId) async {
    final path = await sheetFilePath(sheetId);
    final f = File(path);
    if (!await f.exists()) {
      final emptyJson = utf8.encode(jsonEncode(<String, dynamic>{
        'version': 1,
        'items': <Map<String, dynamic>>[],
      }));
      final enc = await EncryptionService.instance.encryptBytes(Uint8List.fromList(emptyJson));
      await f.writeAsBytes(enc, flush: true);
    }
    return path;
  }

  Future<List<Measurement>> loadAll(String sheetId) async {
    final path = await sheetFilePath(sheetId);
    final f = File(path);

    // Compatibilidad: si no existe .enc, intentar viejo .json (sin cifrar)
    if (!await f.exists()) {
      final legacy = File(path.replaceAll('.enc', '.json'));
      if (await legacy.exists()) {
        final raw = await legacy.readAsString();
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final list = (map['items'] as List? ?? const [])
            .cast<Map<String, dynamic>>()
            .map(Measurement.fromJson)
            .toList(growable: false);
        // migrar a .enc
        await saveAll(sheetId, list);
        await legacy.delete();
        return list;
      }
      return const <Measurement>[];
    }

    final enc = await f.readAsBytes();
    final plain = await EncryptionService.instance.decryptBytes(Uint8List.fromList(enc));
    final map = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    final list = (map['items'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(Measurement.fromJson)
        .toList(growable: false);
    return list;
  }

  Future<void> saveAll(String sheetId, List<Measurement> items) async {
    final path = await sheetFilePath(sheetId);
    final f = File(path);

    final plainMap = <String, dynamic>{
      'version': 1,
      'updatedAt': DateTime.now().toIso8601String(),
      'items': items.map((e) => e.toJson()).toList(),
    };
    final plainBytes = Uint8List.fromList(utf8.encode(jsonEncode(plainMap)));
    final encBytes = await EncryptionService.instance.encryptBytes(plainBytes);

    await f.writeAsBytes(encBytes, flush: true);
  }
}
