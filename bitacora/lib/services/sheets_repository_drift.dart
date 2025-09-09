// lib/services/sheets_repository_drift.dart
import 'package:drift/drift.dart';
import '../data/app_db.dart';

class SheetsRepository {
  final AppDb db;
  SheetsRepository(this.db);

  Future<SheetRow> createSheet({required String name}) async {
    final id = await db.into(db.sheets).insert(SheetsCompanion.insert(
      name: name,
      version: const Value(1),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    ));
    return (db.select(db.sheets)..where((t) => t.id.equals(id))).getSingle();
  }

  Stream<List<SheetRow>> watchSheetsSorted() {
    final q = db.select(db.sheets)
      ..orderBy([
            (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);
    return q.watch();
  }

  Future<List<SheetRow>> getAllSorted() {
    final q = db.select(db.sheets)
      ..orderBy([
            (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);
    return q.get();
  }

  Future<void> deleteById(int id) async {
    await (db.delete(db.sheets)..where((t) => t.id.equals(id))).go();
  }

  Future<void> deleteCascade(int id) async {
    await db.transaction(() async {
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

  // Alias para el caller existente
  Future<void> deleteSheetCascade(int id) => deleteCascade(id);
}
