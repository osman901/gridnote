// lib/data/local_db.dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'local_db.g.dart';

class Sheets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withDefault(const Constant('Planilla'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Entries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sheetId =>
      integer().references(Sheets, #id, onDelete: KeyAction.cascade)();
  TextColumn get note => text().nullable()();
  RealColumn get lat => real().nullable()();
  RealColumn get lon => real().nullable()();
  TextColumn get photoPath => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [Sheets, Entries])
class LocalDB extends _$LocalDB {
  LocalDB._(QueryExecutor e) : super(e);
  static LocalDB? _i;
  factory LocalDB() => _i ??= LocalDB._(_open());

  @override
  int get schemaVersion => 1;

  // Sheets
  Future<int> createSheet(String name) =>
      into(sheets).insert(SheetsCompanion(name: Value(name)));

  Future<List<Sheet>> allSheets() =>
      (select(sheets)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();

  Future<void> renameSheet(int id, String name) =>
      (update(sheets)..where((t) => t.id.equals(id)))
          .write(SheetsCompanion(name: Value(name)));

  Future<int> deleteSheet(int id) =>
      (delete(sheets)..where((t) => t.id.equals(id))).go();

  // Entries
  Future<int> addEmptyEntry(int sheetId) =>
      into(entries).insert(EntriesCompanion(sheetId: Value(sheetId)));

  Future<List<Entry>> bySheet(int sheetId) =>
      (select(entries)..where((e) => e.sheetId.equals(sheetId))).get();

  Future<void> saveEntry({
    required int id,
    String? note,
    double? lat,
    double? lon,
    String? photoPath,
  }) =>
      (update(entries)..where((t) => t.id.equals(id))).write(EntriesCompanion(
        note: Value(note),
        lat: Value(lat),
        lon: Value(lon),
        photoPath: Value(photoPath),
      ));

  Future<int> deleteEntry(int id) =>
      (delete(entries)..where((t) => t.id.equals(id))).go();
}

// Abre la base de datos local (Drift)
LazyDatabase _open() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'bitacora.db'));
    return NativeDatabase.createInBackground(file);
  });
}
