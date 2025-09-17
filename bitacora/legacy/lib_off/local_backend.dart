// lib/services/local_backend.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../models/measurement.dart';
import 'storage_backend.dart';
import 'xlsx_export_service.dart';

class LocalBackend implements StorageBackend {
  LocalBackend({this.boxName = 'measurements', this.keyName = 'hive_key_v1'});

  final String boxName;
  final String keyName;

  // Opciones neutrales para todas las plataformas
  final _secure = const FlutterSecureStorage();

  Box<Map<String, dynamic>>? _box;

  @override
  String get name => 'Almacenamiento local';

  @override
  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(dir.path);

    // Clave AES de 32 bytes persistida en SecureStorage
    var keyB64 = await _secure.read(key: keyName);
    late final List<int> key;
    if (keyB64 == null) {
      final rnd = Hive.generateSecureKey(); // 32 bytes
      keyB64 = base64Encode(rnd);
      await _secure.write(key: keyName, value: keyB64);
      key = rnd;
    } else {
      key = base64Decode(keyB64);
    }

    _box = await Hive.openBox<Map<String, dynamic>>(
      boxName,
      encryptionCipher: HiveAesCipher(key),
    );

    // Seed opcional: 3 filas vacÃƒÆ’Ã‚Â­as mÃƒÆ’Ã‚Â­nimas
    if (_box!.isEmpty) {
      await _box!.addAll(<Map<String, dynamic>>[
        _emptyMap(),
        _emptyMap(),
        _emptyMap(),
      ]);
    }
  }

  Box<Map<String, dynamic>> _ensure() {
    final b = _box;
    if (b == null || !b.isOpen) {
      throw StateError('LocalBackend no inicializado.');
    }
    return b;
  }

  // Mapa base vacÃƒÆ’Ã‚Â­o para una mediciÃƒÆ’Ã‚Â³n (sin const, puro runtime)
  Map<String, dynamic> _emptyMap() => <String, dynamic>{
    'progresiva': '',
    'ohm1m': null,
    'ohm3m': null,
    'observations': '',
    'date': null,
    'latitude': null,
    'longitude': null,
    'photos': <String>[],
  };

  @override
  Future<List<Measurement>> loadAll() async {
    final b = _ensure();
    return b.values
        .map((e) => Measurement.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  @override
  Future<void> saveAll(List<Measurement> items) async {
    final b = _ensure();
    await b.clear();
    final maps =
    items.map((m) => Map<String, dynamic>.from(m.toJson())).toList();
    await b.addAll(maps);
  }

  @override
  Future<File> exportXlsx({
    required String fileName,
    List<String>? headers,
  }) async {
    final data = await loadAll();

    // title = fileName sin extensiÃƒÆ’Ã‚Â³n (XlsxExportService agrega .xlsx)
    var title = fileName.trim();
    if (title.toLowerCase().endsWith('.xlsx')) {
      title = title.substring(0, title.length - 5);
    }

    final svc = XlsxExportService();
    final tmp = await svc.buildFile(
      sheetId: 'local',
      title: title,
      data: data,
      headers: headers,
    );

    // Asegurar el nombre exacto solicitado por el caller
    final dir = await getApplicationDocumentsDirectory();
    final target = File('${dir.path}/$fileName');
    if (tmp.path == target.path) return tmp;

    try {
      if (await target.exists()) await target.delete();
      await tmp.copy(target.path);
      return target;
    } catch (_) {
      // Si falla copiar/renombrar, devolvemos el temporal.
      return tmp;
    }
  }

  @override
  Future<String?> uploadFile(File file) async => file.path;
}
