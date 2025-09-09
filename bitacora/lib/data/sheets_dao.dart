// lib/data/sheets_dao.dart
import 'package:drift/drift.dart';
import 'app_db.dart';

class DuplicateAttachmentException implements Exception {
  final String message;
  DuplicateAttachmentException([this.message = 'Duplicate attachment']);
  @override
  String toString() => message;
}

class SheetsDao {
  final AppDb db;
  SheetsDao(this.db);

  // === SHEETS ===

  Future<SheetRow> createSheet(String name) async {
    final id = await db.into(db.sheets).insert(SheetsCompanion.insert(
      name: name,
      version: const Value(1),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    ));
    return (db.select(db.sheets)..where((t) => t.id.equals(id))).getSingle();
  }

  Stream<List<SheetRow>> watchSortedDesc() {
    final q = db.select(db.sheets)
      ..orderBy([
            (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);
    return q.watch();
  }

  Future<List<SheetRow>> getAllSorted() async {
    final q = db.select(db.sheets)
      ..orderBy([
            (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);
    return q.get();
  }

  Future<SheetRow> getSheet(int sheetId) async {
    return (db.select(db.sheets)..where((t) => t.id.equals(sheetId))).getSingle();
  }

  Future<bool> saveSheetRename({
    required int sheetId,
    required String newName,
    required int expectedVersion,
  }) async {
    final q = db.update(db.sheets)
      ..where((t) => t.id.equals(sheetId) & t.version.equals(expectedVersion));
    final rows = await q.write(
      SheetsCompanion(
        name: Value(newName),
        version: Value(expectedVersion + 1),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return rows == 1;
  }

  Future<void> deleteById(int id) async {
    await (db.delete(db.sheets)..where((t) => t.id.equals(id))).go();
  }

  Future<void> deleteCascade(int id) async {
    await db.transaction(() async {
      // eliminar adjuntos de entradas de esa sheet
      final entryIds = await (db.select(db.entries)..where((e) => e.sheetId.equals(id)))
          .get()
          .then((rows) => rows.map((r) => r.id).toList());

      if (entryIds.isNotEmpty) {
        await (db.delete(db.attachments)..where((a) => a.entryId.isIn(entryIds))).go();
      }

      await (db.delete(db.entries)..where((e) => e.sheetId.equals(id))).go();
      await (db.delete(db.sheets)..where((s) => s.id.equals(id))).go();
    });
  }

  // === ENTRIES ===

  Stream<List<EntryRow>> watchEntriesForSheet(int sheetId) {
    final q = (db.select(db.entries)
      ..where((t) => t.sheetId.equals(sheetId))
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .watch();
    return q;
  }

  Future<List<EntryRow>> getEntriesForSheet(int sheetId) async {
    return (db.select(db.entries)
      ..where((t) => t.sheetId.equals(sheetId))
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .get();
  }

  Future<int> createEntry(int sheetId) async {
    return db.into(db.entries).insert(EntriesCompanion.insert(
      sheetId: sheetId,
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> deleteEntry(int entryId) async {
    await (db.delete(db.attachments)..where((t) => t.entryId.equals(entryId))).go();
    await (db.delete(db.entries)..where((t) => t.id.equals(entryId))).go();
  }

  Future<void> updateEntryTitle(int entryId, String? title) async {
    await (db.update(db.entries)..where((t) => t.id.equals(entryId))).write(
      EntriesCompanion(title: Value(title), updatedAt: Value(DateTime.now())),
    );
  }

  Future<void> updateEntryNote(int entryId, String? note) async {
    await (db.update(db.entries)..where((t) => t.id.equals(entryId))).write(
      EntriesCompanion(note: Value(note), updatedAt: Value(DateTime.now())),
    );
  }

  Future<void> updateEntryLocation(
      int entryId, {
        double? lat,
        double? lng,
        double? accuracy,
        String? provider,
      }) async {
    await (db.update(db.entries)..where((t) => t.id.equals(entryId))).write(
      EntriesCompanion(
        lat: Value(lat),
        lng: Value(lng),
        accuracy: Value(accuracy),
        provider: Value(provider),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // === ATTACHMENTS ===

  Future<void> insertAttachment({
    required int entryId,
    required String path,
    required String thumbPath,
    required int sizeBytes,
    required String hash,
  }) async {
    try {
      await db.into(db.attachments).insert(AttachmentsCompanion.insert(
        entryId: entryId,
        path: path,
        thumbPath: thumbPath,
        sizeBytes: sizeBytes,
        hash: hash,
        createdAt: Value(DateTime.now()),
      ));
    } on SqliteException catch (e) {
      if (e.message.contains('UNIQUE') || e.toString().contains('UNIQUE')) {
        throw DuplicateAttachmentException();
      }
      rethrow;
    }
  }

  Future<int> countAttachmentsForEntry(int entryId) async {
    final exp = db.attachments.id.count();
    final q = db.selectOnly(db.attachments)
      ..addColumns([exp])
      ..where(db.attachments.entryId.equals(entryId));
    final row = await q.getSingleOrNull();
    return row?.read(exp) ?? 0;
  }

  Future<Map<int, int>> getAttachmentCountsMapForSheet(int sheetId) async {
    final countExp = db.attachments.id.count();
    final q = db.selectOnly(db.attachments)
      ..addColumns([db.attachments.entryId, countExp])
      ..where(db.attachments.entryId.isInQuery(
        db.selectOnly(db.entries)
          ..addColumns([db.entries.id])
          ..where(db.entries.sheetId.equals(sheetId)),
      ))
      ..groupBy([db.attachments.entryId]);
    final rows = await q.get();
    final m = <int, int>{};
    for (final r in rows) {
      final entryId = r.read(db.attachments.entryId)!;
      final c = r.read(countExp) ?? 0;
      m[entryId] = c;
    }
    return m;
  }
}
