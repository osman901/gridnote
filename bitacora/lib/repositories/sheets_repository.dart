import 'package:drift/drift.dart' show Value;
import '../data/app_db.dart';

class SheetsRepo {
  SheetsRepo(this.db);
  final AppDb db;

  static const String defaultId = 'default';

  Future<SheetData> initIfNeeded({int columns = 5}) async {
    final existing = await db.fetchSheet(defaultId);
    if (existing != null) return existing;
    await db.upsertSheet(id: defaultId, columns: columns, headers: List.filled(columns, ''));
    // Crea 60 filas vacías persistidas para scroll rápido
    for (var i = 0; i < 60; i++) {
      await db.addRow(defaultId, i, List.filled(columns, ''));
    }
    return (await db.fetchSheet(defaultId))!;
  }

  Future<SheetData?> get() => db.fetchSheet(defaultId);

  Future<void> setHeaders(List<String> headers) =>
      db.upsertSheet(id: defaultId, headers: headers, columns: headers.length);

  Future<RowData> addRow(List<String> cells, int index) async {
    final id = await db.addRow(defaultId, index, cells);
    final s = await db.fetchSheet(defaultId);
    return s!.rows.firstWhere((r) => r.id == id);
  }

  Future<void> saveRow(RowData r) => db.updateRow(r);

  Future<void> removeRow(RowData r) => db.deleteRow(r.id);
}
