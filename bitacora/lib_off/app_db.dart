// lib/data/app_db.dart
import 'package:drift/drift.dart';
import 'package:drift_sqflite/drift_sqflite.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

part 'app_db.g.dart';

@DataClassName('SheetRow')
class Sheets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('EntryRow')
class Entries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sheetId =>
      integer().references(Sheets, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().nullable()();
  TextColumn get note => text().nullable()();
  RealColumn get lat => real().nullable()();
  RealColumn get lng => real().nullable()();
  RealColumn get accuracy => real().nullable()();
  TextColumn get provider => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('AttachmentRow')
class Attachments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get entryId =>
      integer().references(Entries, #id, onDelete: KeyAction.cascade)();
  TextColumn get path => text()();
  TextColumn get thumbPath => text()();
  IntColumn get sizeBytes => integer()();
  TextColumn get hash => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // FIX: Debe ser List<Set<Column>> y no Set<Set<Column>>
  @override
  List<Set<Column<Object>>>? get uniqueKeys => [
    {hash},
  ];
}

@DriftDatabase(tables: [Sheets, Entries, Attachments])
class AppDb extends _$AppDb {
  AppDb()
      : super(
    SqfliteQueryExecutor.inDatabaseFolder(
      path: 'bitacora.db',
      logStatements: kDebugMode,
    ),
  );

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_sheets_created_at ON sheets (created_at)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_entries_sheet_created ON entries (sheet_id, created_at)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_attachments_entry ON attachments (entry_id)',
      );
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_sheets_created_at ON sheets (created_at)',
        );
      }
      if (from < 3) {
        await m.createTable(entries);
        await m.createTable(attachments);
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_entries_sheet_created ON entries (sheet_id, created_at)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_attachments_entry ON attachments (entry_id)',
        );
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      // En sqflite, usá SELECT para PRAGMAs que devuelven valor
      await customSelect('PRAGMA journal_mode = WAL').get();
      await customStatement('PRAGMA synchronous = NORMAL');
      await customStatement('PRAGMA temp_store = MEMORY');
    },
  );
}
