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
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime).named('created_at')();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime).named('updated_at')();
}

class Entries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sheetId => integer().references(Sheets, #id, onDelete: KeyAction.cascade).named('sheet_id')();
  TextColumn get title => text().nullable()();
  TextColumn get note => text().nullable()();
  RealColumn get lat => real().nullable()();
  RealColumn get lng => real().nullable()();
  RealColumn get accuracy => real().nullable()();
  TextColumn get provider => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime).named('created_at')();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime).named('updated_at')();
}

class Attachments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get entryId => integer().references(Entries, #id, onDelete: KeyAction.cascade).named('entry_id')();
  TextColumn get path => text()();
  TextColumn get thumbPath => text().named('thumb_path')();
  IntColumn get sizeBytes => integer().named('size_bytes')();
  TextColumn get hash => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime).named('created_at')();
}

@DriftDatabase(tables: [Sheets, Entries, Attachments])
class LocalDb extends _$LocalDb {
  LocalDb() : super(_open());
  @override
  int get schemaVersion => 1;

  // Sheets
  Future<List<Sheet>> allSheets() =>
      (select(sheets)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();
  Future<Sheet?> getSheet(int id) =>
      (select(sheets)..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<int> createSheet(String name) =>
      into(sheets).insert(SheetsCompanion.insert(name: Value(name)));
  Future<void> renameSheet(int id, String name) =>
      (update(sheets)..where((t) => t.id.equals(id))).write(SheetsCompanion(name: Value(name)));
  Future<void> deleteSheet(int id) =>
      (delete(sheets)..where((t) => t.id.equals(id))).go();

  // Entries
  Future<List<Entry>> entriesForSheet(int sheetId) =>
      (select(entries)..where((t) => t.sheetId.equals(sheetId))..orderBy([(t)=>OrderingTerm.desc(t.updatedAt)])).get();
  Future<int> createEntry(int sheetId, {String? title}) =>
      into(entries).insert(EntriesCompanion.insert(sheetId: sheetId, title: title==null? const Value.absent():Value(title)));
  Future<void> updateEntry(int id, {String? title,String? note,double? lat,double? lng,double? accuracy,String? provider}) =>
      (update(entries)..where((t)=>t.id.equals(id))).write(EntriesCompanion(
        title: title==null? const Value.absent():Value(title),
        note: note==null? const Value.absent():Value(note),
        lat: lat==null? const Value.absent():Value(lat),
        lng: lng==null? const Value.absent():Value(lng),
        accuracy: accuracy==null? const Value.absent():Value(accuracy),
        provider: provider==null? const Value.absent():Value(provider),
        updatedAt: Value(DateTime.now()),
      ));
  Future<void> deleteEntry(int id) =>
      (delete(entries)..where((t)=>t.id.equals(id))).go();

  // Attachments
  Future<int> addAttachment(AttachmentsCompanion c) => into(attachments).insert(c);
  Future<List<Attachment>> attachmentsForEntry(int entryId) =>
      (select(attachments)..where((t)=>t.entryId.equals(entryId))).get();
  Future<void> deleteAttachment(int id) =>
      (delete(attachments)..where((t)=>t.id.equals(id))).go();
}

LazyDatabase _open() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'bitacora.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
