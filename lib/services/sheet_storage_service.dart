import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Guarda las FILAS de cada planilla.
/// Clave = sheetId (String), Valor = List<Map<String,dynamic>>
class SheetStorageService {
  SheetStorageService._();
  static final SheetStorageService instance = SheetStorageService._();

  static const String _boxName = 'sheets_data';
  late Box _box;

  Future<void> init() async {
    if (Hive.isBoxOpen(_boxName)) {
      _box = Hive.box(_boxName);
    } else {
      _box = await Hive.openBox(_boxName);
    }
  }

  ValueListenable<Box> listenableFor(String sheetId) =>
      _box.listenable(keys: [sheetId]);

  List<Map<String, dynamic>> readRows(String sheetId) {
    final raw = _box.get(sheetId);
    if (raw is List) {
      return raw
          .map<Map<String, dynamic>>((e) =>
      (e is Map) ? Map<String, dynamic>.from(e) : <String, dynamic>{})
          .toList(growable: true);
    }
    return <Map<String, dynamic>>[];
  }

  Future<void> writeRows(String sheetId, List<Map<String, dynamic>> rows) async {
    final list = rows.map((m) => Map<String, dynamic>.from(m)).toList();
    await _box.put(sheetId, list);
  }

  Future<void> upsertRow(
      String sheetId, {
        required int index,
        required Map<String, dynamic> row,
      }) async {
    final rows = readRows(sheetId);
    if (index < 0) return;
    if (index >= rows.length) {
      rows.add(Map<String, dynamic>.from(row));
    } else {
      rows[index] = Map<String, dynamic>.from(row);
    }
    await writeRows(sheetId, rows);
  }

  Future<void> deleteRow(String sheetId, int index) async {
    final rows = readRows(sheetId);
    if (index < 0 || index >= rows.length) return;
    rows.removeAt(index);
    await writeRows(sheetId, rows);
  }

  Future<void> clearSheet(String sheetId) async {
    await _box.put(sheetId, <Map<String, dynamic>>[]);
  }

  Future<void> clearAllSheets() async {
    await _box.clear();
  }

  List<Map<String, dynamic>> snapshot(String sheetId) =>
      List<Map<String, dynamic>>.unmodifiable(readRows(sheetId));
}