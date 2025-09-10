// lib/services/free_sheet_service.dart
import 'dart:math';
import 'package:hive/hive.dart';
import '../models/free_sheet.dart';

class FreeSheetService {
  FreeSheetService._();
  static final FreeSheetService instance = FreeSheetService._();

  Box<Map>? _box;
  Future<void> _ensure() async {
    _box ??= await Hive.openBox<Map>('free_sheets');
  }

  String _newId() => '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 32)}';

  Future<FreeSheetData> create({required String name}) async {
    await _ensure();
    final d = FreeSheetData(
      id: _newId(),
      name: name,
      createdAt: DateTime.now(),
      headers: [''],
      rows: List.generate(8, (_) => ['']),
    );
    d.ensureWidth(1);
    d.ensureHeight(8);
    await save(d);
    return d;
  }

  Future<FreeSheetData?> get(String id) async {
    await _ensure();
    final raw = _box!.get(id);
    if (raw == null) return null;
    return FreeSheetData.fromMap(raw);
  }

  Future<void> save(FreeSheetData data) async {
    await _ensure();
    await _box!.put(data.id, Map<String, dynamic>.from(data.toMap()));
  }

  Future<FreeSheetData> addColumn(FreeSheetData d, {String title = ''}) async {
    d.headers.add(title);
    for (final r in d.rows) {
      r.add('');
    }
    await save(d);
    return d;
  }

  Future<FreeSheetData> addRow(FreeSheetData d) async {
    d.rows.add(List.filled(d.headers.length, ''));
    await save(d);
    return d;
  }
}
