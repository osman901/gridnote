// lib/data/sheets_dao.dart
import 'package:drift/drift.dart' as drift;

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
    final id = await db.into(db.sheets).insert(
      SheetsCompanion.insert(
        name: name,
        version: const drift.Value(1),
        createdAt: drift.Value(DateTime.now()),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
    return (db.select(db.sheets)..where((t) => t.id.equals(id))).getSingle();
  }

  Stream<List<SheetRow>> watchSortedDesc() {
    final q = db.select(db.sheets)
      ..orderBy([
            (t) => drift.OrderingTerm(
          expression: t.updatedAt,
          mode: drift.OrderingMode.desc,
        ),
            (t) => drift.OrderingTerm(
          expression: t.createdAt,
          mode: drift.OrderingMode.desc,
        ),
      ]);
    return q.watch();
  }

  Future<List<SheetRow>> getAllSorted() async {
    final q = db.select(db.sheets)
      ..orderBy([
            (t) => drift.OrderingTerm(
          expression: t.updatedAt,
          mode: drift.OrderingMode.desc,
        ),
            (t) => drift.OrderingTerm(
          expression: t.createdAt,
          mode: drift.OrderingMode.desc,
        ),
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
        name: drift.Value(newName),
        version: drift.Value(expectedVersion + 1),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
    return rows == 1;
  }

  Future<void> deleteById(int id) async {
    await (db.delete(db.sheets)..where((t) => t.id.equals(id))).go();
  }

  Future<void> deleteCascade(int id) async {
    await db.transaction(() async {
      // IDs de las entradas de esa sheet
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
      ..orderBy([
            (t) => drift.OrderingTerm(
          expression: t.createdAt,
          mode: drift.OrderingMode.desc,
        )
      ]))
        .watch();
    return q;
  }

  Future<List<EntryRow>> getEntriesForSheet(int sheetId) async {
    return (db.select(db.entries)
      ..where((t) => t.sheetId.equals(sheetId))
      ..orderBy([
            (t) => drift.OrderingTerm(
          expression: t.createdAt,
          mode: drift.OrderingMode.desc,
        )
      ]))
        .get();
  }

  Future<int> createEntry(int sheetId) async {
    return db.into(db.entries).insert(
      EntriesCompanion.insert(
        sheetId: sheetId,
        createdAt: drift.Value(DateTime.now()),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteEntry(int entryId) async {
    await (db.delete(db.attachments)..where((t) => t.entryId.equals(entryId))).go();
    await (db.delete(db.entries)..where((t) => t.id.equals(entryId))).go();
  }

  Future<void> updateEntryTitle(int entryId, String? title) async {
    await (db.update(db.entries)..where((t) => t.id.equals(entryId))).write(
      EntriesCompanion(
        title: drift.Value(title),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateEntryNote(int entryId, String? note) async {
    await (db.update(db.entries)..where((t) => t.id.equals(entryId))).write(
      EntriesCompanion(
        note: drift.Value(note),
        updatedAt: drift.Value(DateTime.now()),
      ),
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
        lat: drift.Value(lat),
        lng: drift.Value(lng),
        accuracy: drift.Value(accuracy),
        provider: drift.Value(provider),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
  }

  /// Sugerencias de títulos usados recientemente en una sheet.
  Future<List<String>> suggestionsForSheetTitles(int sheetId) async {
    final rows = await (db.select(db.entries)
      ..where((e) => e.sheetId.equals(sheetId) & e.title.isNotNull())
      ..orderBy([
            (e) => drift.OrderingTerm(
          expression: e.updatedAt,
          mode: drift.OrderingMode.desc,
        )
      ])
      ..limit(32))
        .get();

    final set = <String>{};
    for (final r in rows) {
      final t = (r.title ?? '').trim();
      if (t.isNotEmpty) {
        set.add(t);
        if (set.length >= 8) break;
      }
    }
    return set.toList();
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
      await db.into(db.attachments).insert(
        AttachmentsCompanion.insert(
          entryId: entryId,
          path: path,
          thumbPath: thumbPath,
          sizeBytes: sizeBytes,
          hash: hash,
          createdAt: drift.Value(DateTime.now()),
        ),
      );
    } catch (e) {
      // Detecta violación de UNIQUE por mensaje (driver-dependiente)
      final msg = e.toString();
      if (msg.contains('UNIQUE') || msg.contains('unique')) {
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
      ..where(
        db.attachments.entryId.isInQuery(
          db.selectOnly(db.entries)
            ..addColumns([db.entries.id])
            ..where(db.entries.sheetId.equals(sheetId)),
        ),
      )
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
