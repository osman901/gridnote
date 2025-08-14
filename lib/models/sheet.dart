// lib/models/sheet.dart
import 'dart:math';
import 'package:hive/hive.dart';

part 'sheet.g.dart';

/// Modelo de una planilla. Contiene metadatos (id, nombre, fechas, ubicación opcional).
@HiveType(typeId: 100)
class SheetMeta {
  @HiveField(0)
  final String id;
  @HiveField(1)
  String name;
  @HiveField(2)
  DateTime createdAt;
  @HiveField(3)
  DateTime updatedAt;
  @HiveField(4)
  double? lat;
  @HiveField(5)
  double? lon;
  @HiveField(6)
  String? cloudUrl;

  SheetMeta({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.lat,
    this.lon,
    this.cloudUrl,
  });

  SheetMeta copyWith({
    String? name,
    DateTime? updatedAt,
    double? lat,
    double? lon,
    String? cloudUrl,
  }) {
    return SheetMeta(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      cloudUrl: cloudUrl ?? this.cloudUrl,
    );
  }
}

/// Repositorio local de planillas.
/// Usa Hive para guardar y recuperar metadatos de planillas y filas.
class SheetsStore {
  static const _boxMeta = 'sheets_meta_v1';
  static const _boxRows = 'sheets_rows_v1';
  static bool _initDone = false;
  static late Box<SheetMeta> _meta;
  static late Box<List<List<String>>> _rows;

  static Future<void> ensureInit() async {
    if (_initDone) return;
    if (!Hive.isAdapterRegistered(100)) {
      Hive.registerAdapter(SheetMetaAdapter());
    }
    _meta = await Hive.openBox<SheetMeta>(_boxMeta);
    _rows = await Hive.openBox<List<List<String>>>(_boxRows);
    _initDone = true;
  }

  static List<SheetMeta> all() {
    final list = _meta.values.toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  static Future<SheetMeta> create(String name) async {
    final id =
        '${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(9999)}';
    final now = DateTime.now();
    final meta = SheetMeta(
      id: id,
      name: name,
      createdAt: now,
      updatedAt: now,
    );
    await _meta.add(meta);
    await _rows.put(id, []);
    return meta;
  }

  static List<List<String>> getRows(String sheetId) {
    return _rows.get(sheetId) ?? [];
  }

  static Future<void> saveRows(String sheetId, List<List<String>> rows) async {
    await _rows.put(sheetId, rows);
    final index = _meta.values.toList().indexWhere((e) => e.id == sheetId);
    if (index != -1) {
      final key = _meta.keyAt(index);
      final meta = _meta.getAt(index);
      if (meta != null) {
        await _meta.put(key, meta.copyWith(updatedAt: DateTime.now()));
      }
    }
  }

  static Future<void> rename(SheetMeta sheet, String newName) async {
    final idx = _meta.values.toList().indexWhere((e) => e.id == sheet.id);
    if (idx != -1) {
      final key = _meta.keyAt(idx);
      final updated = sheet.copyWith(name: newName, updatedAt: DateTime.now());
      await _meta.put(key, updated);
    }
  }

  static Future<void> delete(SheetMeta sheet) async {
    final idx = _meta.values.toList().indexWhere((e) => e.id == sheet.id);
    if (idx != -1) await _meta.deleteAt(idx);
    await _rows.delete(sheet.id);
  }
}
