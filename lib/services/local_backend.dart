// lib/services/local_backend.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../models/measurement.dart'; // MeasurementAdapter (g.dart)
import 'storage_backend.dart';
import 'xlsx_export_service.dart';

class LocalBackend implements StorageBackend {
  LocalBackend({this.boxName = 'measurements', this.keyName = 'hive_key_v1'});

  final String boxName;
  final String keyName;

  final _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Box<Measurement>? _box;

  @override
  String get name => 'Almacenamiento local';

  @override
  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(dir.path);

    Hive.registerAdapter(MeasurementAdapter());

    // Clave AES persistida en SecureStorage
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

    _box = await Hive.openBox<Measurement>(
      boxName,
      encryptionCipher: HiveAesCipher(key),
    );

    // Seed inicial (opcional)
    if (_box!.isEmpty) {
      await _box!.addAll(<Measurement>[
        Measurement.empty(),
        Measurement.empty(),
        Measurement.empty(),
      ]);
    }
  }

  Box<Measurement> _ensure() {
    final b = _box;
    if (b == null || !b.isOpen) {
      throw StateError('LocalBackend no inicializado.');
    }
    return b;
  }

  @override
  Future<List<Measurement>> loadAll() async {
    final b = _ensure();
    return b.values.toList(growable: false);
  }

  @override
  Future<void> saveAll(List<Measurement> items) async {
    final b = _ensure();
    await b.clear();
    await b.addAll(items); // inserción en bloque
  }

  @override
  Future<File> exportXlsx({
    required String fileName,
    List<String>? headers,
  }) async {
    final data = await loadAll();

    // title = fileName sin extensión (XlsxExportService agrega .xlsx)
    var title = fileName.trim();
    if (title.toLowerCase().endsWith('.xlsx')) {
      title = title.substring(0, title.length - 5);
    }
    final svc = XlsxExportService();
    final tmp = await svc.buildFile(
      sheetId: 'local', // ID genérico; si tenés uno real, pásalo acá
      title: title,
      data: data,
      headers: headers,
    );

    // Asegurar el nombre exacto solicitado por el caller (fileName)
    final dir = await getApplicationDocumentsDirectory();
    final target = File('${dir.path}/$fileName');
    if (tmp.path == target.path) return tmp;
    try {
      if (await target.exists()) await target.delete();
      await tmp.copy(target.path);
      return target;
    } catch (_) {
      // Si no se puede renombrar/copiar, devolvemos el temporal igual.
      return tmp;
    }
  }

  @override
  Future<String?> uploadFile(File file) async => file.path;
}
