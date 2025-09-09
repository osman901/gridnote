// lib/repositories/sheets_repository.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/local_db.dart';
import '../models/measurement.dart';
import '../models/sheet_meta.dart';

typedef Entry = Measurement;
typedef Sheet = SheetMeta;

/// Utilidades de conversiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n defensiva desde `Object?` de LocalDB
Sheet _coerceSheet(Object? o) {
  if (o is Sheet) return o;

  // Map<String, dynamic> ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ Sheet
  if (o is Map) {
    final m = Map<String, dynamic>.from(o as Map);
    return Sheet.fromJson(m);
  }

  // Fallback mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­nimo (evita crashear si la DB devuelve algo inesperado)
  final idStr = o?.toString() ?? '';
  return Sheet(
    id: idStr,
    name: idStr.isEmpty ? 'Planilla' : 'Planilla $idStr',
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );
}

Entry _coerceEntry(Object? o) {
  if (o is Entry) return o;

  if (o is Map) {
    final m = Map<String, dynamic>.from(o as Map);
    return Entry.fromJson(m);
  }

  // Fallback: fila vacÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­a con id si se puede parsear
  final id = int.tryParse(o?.toString() ?? '');
  return Entry(
    id: id,
    progresiva: '',
    observations: '',
    date: DateTime.now(),
    photos: const <String>[],
  );
}

class SheetsRepository {
  SheetsRepository(this.db);
  final LocalDB db;

  Future<Sheet> createSheet({String? name}) async {
    final createdId = await db.createSheet(name ?? 'Planilla ${DateTime.now()}');

    // Si la DB aÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºn no refleja el insert, devolvemos una Sheet mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­nima vÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡lida.
    try {
      final list = await db.allSheets();
      final sheets = list.map(_coerceSheet).toList();
      final match = sheets.firstWhere(
            (s) => s.id == createdId.toString(),
        orElse: () => Sheet(
          id: createdId.toString(),
          name: name ?? 'Planilla',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      return match;
    } catch (_) {
      return Sheet(
        id: createdId.toString(),
        name: name ?? 'Planilla',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  Future<List<Sheet>> getSheets() async {
    final list = await db.allSheets();
    return list.map(_coerceSheet).toList();
  }

  Future<void> renameSheet(int id, String name) => db.renameSheet(id, name);

  Future<int> deleteSheet(int id) => db.deleteSheet(id);

  Future<Entry> addRow(int sheetId) async {
    final newId = await db.addEmptyEntry(sheetId);

    try {
      final list = await db.bySheet(sheetId);
      final entries = list.map(_coerceEntry).toList();
      final match = entries.firstWhere(
            (e) => e.id == newId,
        orElse: () => Entry(
          id: newId,
          progresiva: '',
          observations: '',
          date: DateTime.now(),
          photos: const <String>[],
        ),
      );
      return match;
    } catch (_) {
      return Entry(
        id: newId,
        progresiva: '',
        observations: '',
        date: DateTime.now(),
        photos: const <String>[],
      );
    }
  }

  Future<List<Entry>> rows(int sheetId) async {
    final list = await db.bySheet(sheetId);
    return list.map(_coerceEntry).toList();
  }

  Future<void> saveRow(Entry e) async {
    await db.saveEntry(
      id: e.id!, // guardamos filas existentes
      note: e.observations,
      lat: e.latitude,
      lon: e.longitude,
      photoPath: (e.photos.isNotEmpty ? e.photos.last : null),
    );
  }

  /// Copia la imagen al almacenamiento interno y devuelve su ruta persistente.
  Future<String> persistImage(
      File src, {
        required int sheetId,
        required int entryId,
      }) async {
    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(dir.path, 'images', 'sheet_$sheetId'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    final ext = p.extension(src.path).isEmpty ? '.jpg' : p.extension(src.path);
    final name = 'e${entryId}_${DateTime.now().millisecondsSinceEpoch}$ext';
    final dest = File(p.join(imagesDir.path, name));
    await src.copy(dest.path);
    return dest.path;
  }
}
