import 'dart:io';
import 'package:drift/drift.dart' as drift;
import '../data/app_db.dart';

class SheetsRepository {
  SheetsRepository(this.db);
  final AppDb db;

  Future<SheetRow> createSheet({required String name}) async {
    final id = await db.into(db.sheets).insert(
      SheetsCompanion(
        name: drift.Value(name),
        version: const drift.Value(1),
        createdAt: drift.Value(DateTime.now()),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
    return (db.select(db.sheets)..where((t) => t.id.equals(id))).getSingle();
  }

  Stream<List<SheetRow>> watchSheetsSorted() {
    final q = db.select(db.sheets)
      ..orderBy([
            (t) => drift.OrderingTerm(expression: t.updatedAt, mode: drift.OrderingMode.desc),
            (t) => drift.OrderingTerm(expression: t.createdAt, mode: drift.OrderingMode.desc),
      ]);
    return q.watch();
  }

  Future<SheetRow?> getSheet(int id) async {
    return (db.select(db.sheets)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> renameSheet({required int id, required String name}) {
    return (db.update(db.sheets)..where((t) => t.id.equals(id))).write(
      SheetsCompanion(
        name: drift.Value(name),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteSheetCascade(int sheetId) async {
    await db.transaction(() async {
      final entryIds = await (db.select(db.entries)..where((t) => t.sheetId.equals(sheetId)))
          .map((e) => e.id)
          .get();

      if (entryIds.isNotEmpty) {
        await (db.delete(db.attachments)..where((t) => t.entryId.isIn(entryIds))).go();
      }
      await (db.delete(db.entries)..where((t) => t.sheetId.equals(sheetId))).go();
      await (db.delete(db.sheets)..where((t) => t.id.equals(sheetId))).go();
    });
  }

  // *** Nuevas funciones para entradas y adjuntos ***

  /// Stream de entradas de una planilla, ordenadas por creación (desc).
  Stream<List<EntryRow>> watchEntries(int sheetId) {
    final q = db.select(db.entries)
      ..where((t) => t.sheetId.equals(sheetId))
      ..orderBy([(t) => drift.OrderingTerm(expression: t.createdAt, mode: drift.OrderingMode.desc)]);
    return q.watch();
  }

  /// Añade una entrada. Retorna el ID de la entrada creada.
  Future<int> addEntry({
    required int sheetId,
    String? title,
    String? note,
    double? lat,
    double? lng,
    double? accuracy,
    String? provider,
  }) async {
    final id = await db.into(db.entries).insert(EntriesCompanion(
      sheetId: drift.Value(sheetId),
      title: drift.Value(title),
      note: drift.Value(note),
      lat: drift.Value(lat),
      lng: drift.Value(lng),
      accuracy: drift.Value(accuracy),
      provider: drift.Value(provider),
      createdAt: drift.Value(DateTime.now()),
      updatedAt: drift.Value(DateTime.now()),
    ));

    // Actualiza updatedAt de la planilla
    await (db.update(db.sheets)..where((t) => t.id.equals(sheetId))).write(
      SheetsCompanion(updatedAt: drift.Value(DateTime.now())),
    );
    return id;
  }

  Future<int> updateEntry(EntryRow entry) {
    return (db.update(db.entries)..where((t) => t.id.equals(entry.id))).write(
      EntriesCompanion(
        title: drift.Value(entry.title),
        note: drift.Value(entry.note),
        lat: drift.Value(entry.lat),
        lng: drift.Value(entry.lng),
        accuracy: drift.Value(entry.accuracy),
        provider: drift.Value(entry.provider),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteEntry(int id) async {
    // Borrar adjuntos asociados
    await (db.delete(db.attachments)..where((t) => t.entryId.equals(id))).go();
    await (db.delete(db.entries)..where((t) => t.id.equals(id))).go();
  }

  /// Stream de adjuntos para una entrada.
  Stream<List<AttachmentRow>> watchAttachmentsForEntry(int entryId) {
    return (db.select(db.attachments)..where((t) => t.entryId.equals(entryId))).watch();
  }

  /// Añade un adjunto (imagen) a una entrada.
  Future<int> addAttachment({
    required int entryId,
    required String path,
    required String thumbPath,
    required int sizeBytes,
    required String hash,
  }) async {
    return await db.into(db.attachments).insert(AttachmentsCompanion(
      entryId: drift.Value(entryId),
      path: drift.Value(path),
      thumbPath: drift.Value(thumbPath),
      sizeBytes: drift.Value(sizeBytes),
      hash: drift.Value(hash),
      createdAt: drift.Value(DateTime.now()),
    ));
  }

  Future<void> deleteAttachment(int id) {
    return (db.delete(db.attachments)..where((t) => t.id.equals(id))).go();
  }
}
