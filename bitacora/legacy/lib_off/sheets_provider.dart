// lib/providers/sheets_provider.dart
// Conecta UI ⇄ Repo ⇄ Drift usando Riverpod.
// Ajustá los imports a tu ruta real de la base de datos y modelos.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitacora/data/local_db.dart'; // <-- ajustá a tu esquema real
// import 'package:bitacora/data/models.dart'; // si tus modelos están en otro archivo

/// Instancia única de la base de datos.
final dbProvider = Provider<LocalDb>((ref) {
  return LocalDb();
});

/// Repositorio para la tabla de entradas.
final sheetsRepoProvider = Provider<SheetsRepo>((ref) {
  return SheetsRepo(ref.watch(dbProvider));
});

/// Stream de entradas para un sheetId.
final entriesStreamProvider = StreamProvider.family<List<Entry>, int>((ref, sheetId) {
  return ref.watch(sheetsRepoProvider).watchEntriesForSheet(sheetId);
});

class SheetsRepo {
  SheetsRepo(this._db);
  final LocalDb _db;

  // LECTURA: devuelve stream de entradas por planilla.
  Stream<List<Entry>> watchEntriesForSheet(int sheetId) {
    return _db.entriesForSheetStream(sheetId);
  }

  // CREAR FILA
  Future<int> createEntry(int sheetId, {String? title}) async {
    final id = await _db.createEntry(sheetId, title: title ?? '');
    await _db.touchSheet(sheetId); // actualiza fecha de modificación
    return id;
  }

  // BORRAR FILA
  Future<void> deleteEntry(int entryId) async {
    final entry = await (_db.select(_db.entries)
      ..where((t) => t.id.equals(entryId)))
        .getSingleOrNull();
    await _db.deleteEntry(entryId);
    if (entry != null) {
      await _db.touchSheet(entry.sheetId);
    }
  }

  // Actualizar una celda textual (ajustar mapeo a tu DB real)
  static const List<String> _fieldMap = <String>['title', 'note', 'col3', 'col4', 'col5'];

  Future<void> updateCell(int entryId, int colIndex, String value) async {
    final field = (colIndex >= 0 && colIndex < _fieldMap.length) ? _fieldMap[colIndex] : '';
    switch (field) {
      case 'title':
        await _db.updateEntry(entryId, title: value);
        break;
      case 'note':
        await _db.updateEntry(entryId, note: value);
        break;
      case 'col3':
        await _db.updateEntry(entryId, col3: value);
        break;
      case 'col4':
        await _db.updateEntry(entryId, col4: value);
        break;
      case 'col5':
        await _db.updateEntry(entryId, col5: value);
        break;
      default:
      // Si usás JSON u otro campo genérico, ajustá aquí.
        break;
    }
  }

  // Ubicación
  Future<void> setLocation(int entryId, double lat, double lng, {double accuracy = 0}) async {
    await _db.updateEntry(
      entryId,
      lat: lat,
      lng: lng,
      accuracy: accuracy,
      provider: 'gps',
    );
  }

  // FOTOS
  Future<void> setPhotos(int entryId, List<String> photoPaths) async {
    await _db.transaction(() async {
      // elimina adjuntos previos
      await (_db.delete(_db.attachments)..where((t) => t.entryId.equals(entryId))).go();
      // inserta nuevos
      for (final path in photoPaths) {
        await _db.addAttachment(
          AttachmentsCompanion.insert(
            entryId: entryId,
            path: path,
            thumbPath: path, // reemplazalo por miniaturas reales si las generás
            sizeBytes: 0,
            hash: path,       // placeholder: poné hash real si es necesario
          ),
        );
      }
    });
  }
}
