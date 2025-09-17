import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/free_sheet.dart';

class FreeSheetService {
  FreeSheetService._();
  static final FreeSheetService instance = FreeSheetService._();

  Future<Directory> _baseDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final d = Directory(p.join(docs.path, 'free_sheets'));
    if (!await d.exists()) {
      await d.create(recursive: true);
    }
    return d;
  }

  Future<File> _fileFor(String id) async {
    final dir = await _baseDir();
    return File(p.join(dir.path, '$id.json'));
  }

  /// Crea una planilla nueva (2 columnas por defecto, 8 filas).
  Future<FreeSheetData> create({required String name}) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final d = FreeSheetData(
      id: id,
      name: name,
      headers: ['Col 1', 'Col 2'],
      rows: <List<String>>[],
    );
    d.ensureHeight(8);
    await save(d);
    return d;
  }

  /// Obtiene una planilla por id (o null si no existe).
  Future<FreeSheetData?> get(String id) async {
    final f = await _fileFor(id);
    if (!await f.exists()) return null;
    final txt = await f.readAsString();
    return FreeSheetData.decode(txt);
  }

  /// Persiste los cambios en disco.
  Future<void> save(FreeSheetData data) async {
    data.updatedAt = DateTime.now();
    final f = await _fileFor(data.id);
    await f.writeAsString(data.encode(), flush: true);
  }

  /// Agrega columna al final con título [title].
  Future<FreeSheetData> addColumn(
      FreeSheetData data, {
        required String title,
      }) async {
    data.headers.add(title);
    for (final r in data.rows) {
      r.add('');
    }
    await save(data);
    return data;
  }

  /// Agrega una fila vacía (tantas celdas como headers).
  Future<FreeSheetData> addRow(FreeSheetData data) async {
    data.rows.add(List.filled(data.headers.length, ''));
    await save(data);
    return data;
  }
}
