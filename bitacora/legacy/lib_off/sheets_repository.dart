// lib/repositories/sheets_repository.dart
import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/app_db.dart'; // <-- IMPORTA AppDb y las Row classes

/// Repositorio para AppDb (Drift) con tipos: SheetRow / EntryRow / AttachmentRow.
class SheetsRepository {
  SheetsRepository(this.db);
  final AppDb db;

  // ----------------- SHEETS -----------------

  /// Crea una planilla y devuelve la fila creada.
  Future<SheetRow> createSheet({required String name}) async {
    final id = await db.into(db.sheets).insert(
      SheetsCompanion.insert(
        name: name,
        version: const drift.Value(1),
        createdAt: drift.Value(DateTime.now()),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
    final s =
    await (db.select(db.sheets)..where((t) => t.id.equals(id))).getSingleOrNull();
    // No construimos a mano: devolvemos lo que haya o un fallback mínimo coherente con AppDb
    return s ??
        SheetRow(
          id: id,
          name: name,
          version: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
  }

  Future<List<SheetRow>> getSheets() async {
    final q = db.select(db.sheets)
      ..orderBy([
            (t) => drift.OrderingTerm(expression: t.updatedAt, mode: drift.OrderingMode.desc),
            (t) => drift.OrderingTerm(expression: t.createdAt, mode: drift.OrderingMode.desc),
      ]);
    return q.get();
  }

  Future<void> renameSheet(int id, String name) async {
    await (db.update(db.sheets)..where((t) => t.id.equals(id))).write(
      SheetsCompanion(
        name: drift.Value(name),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
  }

  /// Borra la planilla. Si tu esquema tiene FK ON DELETE CASCADE, Entries/Attachments se borran solos.
  Future<void> deleteSheetCascade(int sheetId) async {
    // Si querés asegurar borrado físico de fotos, primero recuperá adjuntos y borrá archivos.
    // Ejemplo (opcional):
    // final entryIds = await (db.select(db.entries)..where((t) => t.sheetId.equals(sheetId)))
    //     .map((e) => e.id)
    //     .get();
    // final atts = await (db.select(db.attachments)..where((t) => t.entryId.isIn(entryIds))).get();
    // for (final a in atts) { File(a.path).existsSync() ? File(a.path).deleteSync() : null; }

    await (db.delete(db.sheets)..where((t) => t.id.equals(sheetId))).go();
  }

  // ----------------- ENTRIES -----------------

  Future<int> addRow(int sheetId, {String? title}) async {
    final id = await db.into(db.entries).insert(
      EntriesCompanion.insert(
        sheetId: sheetId,
        title: drift.Value(title),
        createdAt: drift.Value(DateTime.now()),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
    // touch sheet
    await (db.update(db.sheets)..where((t) => t.id.equals(sheetId))).write(
      SheetsCompanion(updatedAt: drift.Value(DateTime.now())),
    );
    return id;
  }

  Future<List<EntryRow>> rows(int sheetId) async {
    final q = db.select(db.entries)
      ..where((t) => t.sheetId.equals(sheetId))
      ..orderBy([
            (t) => drift.OrderingTerm(expression: t.createdAt, mode: drift.OrderingMode.desc),
      ]);
    return q.get();
  }

  /// Guarda cambios en una entrada. Usá los campos reales del EntryRow de AppDb.
  Future<void> saveRow(EntryRow e) async {
    await (db.update(db.entries)..where((t) => t.id.equals(e.id))).write(
      EntriesCompanion(
        title: drift.Value(e.title),
        note: drift.Value(e.note),
        lat: drift.Value(e.lat),
        lng: drift.Value(e.lng),
        accuracy: drift.Value(e.accuracy),
        provider: drift.Value(e.provider),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
    // touch sheet
    await (db.update(db.sheets)..where((t) => t.id.equals(e.sheetId))).write(
      SheetsCompanion(updatedAt: drift.Value(DateTime.now())),
    );
  }

  Future<void> deleteEntry(int entryId) async {
    await (db.delete(db.entries)..where((t) => t.id.equals(entryId))).go();
  }

  // ----------------- ATTACHMENTS -----------------

  Future<int> addAttachment({
    required int entryId,
    required String path,
    required String thumbPath,
    required int sizeBytes,
    required String hash,
  }) {
    return db.into(db.attachments).insert(
      AttachmentsCompanion.insert(
        entryId: entryId,
        path: path,
        thumbPath: thumbPath,
        sizeBytes: sizeBytes,
        hash: hash,
        createdAt: drift.Value(DateTime.now()),
      ),
    );
  }

  Future<List<AttachmentRow>> attachmentsForEntry(int entryId) async {
    final q = db.select(db.attachments)..where((t) => t.entryId.equals(entryId));
    return q.get();
  }

  Future<void> deleteAttachment(int id) async {
    await (db.delete(db.attachments)..where((t) => t.id.equals(id))).go();
  }

  // ----------------- UTIL: copiar imagen a almacenamiento interno -----------------

  /// Copia `src` al directorio privado y devuelve su ruta.
  Future<String> persistImage(File src,
      {required int sheetId, required int entryId}) async {
    final dir = await getApplicationDocumentsDirectory();
    final imagesDir =
    Directory(p.join(dir.path, 'images', 'sheet_$sheetId'))..createSync(recursive: true);

    final ext = p.extension(src.path).isEmpty ? '.jpg' : p.extension(src.path);
    final name = 'e${entryId}_${DateTime.now().millisecondsSinceEpoch}$ext';
    final dest = File(p.join(imagesDir.path, name));
    await src.copy(dest.path);
    return dest.path;
  }
}
