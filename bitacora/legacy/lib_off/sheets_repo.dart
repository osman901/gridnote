// lib/repositories/sheets_repo.dart
import '../data/local_db.dart';

class SheetsRepo {
  SheetsRepo(this.db);
  final LocalDb db;

  // -------- Sheets --------
  Future<List<Sheet>> listSheets() => db.allSheets();
  Future<Sheet?> getSheet(int id) => db.getSheet(id);
  Future<int> newSheet(String name) => db.createSheet(name);
  Future<void> renameSheet(int id, String name) => db.renameSheet(id, name);
  Future<void> deleteSheet(int id) => db.deleteSheet(id);

  // -------- Entries --------
  Future<List<Entry>> listEntries(int sheetId) => db.entriesForSheet(sheetId);

  /// Tu LocalDb actual no acepta named params aquí.
  Future<int> newEntry(int sheetId, {
    String? title,
    String? note,
    double? lat,
    double? lng,
    double? accuracy,
    String? provider,
  }) => db.createEntry(sheetId);

  /// Ídem: si tu LocalDb no define named params, llamamos al básico.
  Future<void> updateEntry(int id, {
    String? title,
    String? note,
    double? lat,
    double? lng,
    double? accuracy,
    String? provider,
  }) => db.updateEntry(id);

  Future<void> deleteEntry(int id) => db.deleteEntry(id);

  // -------- Attachments --------
  Future<int> addAttachment({
    required int entryId,
    required String path,
    required String thumbPath,
    required int sizeBytes,
    required String hash,
  }) => db.addAttachment(
    AttachmentsCompanion.insert(
      entryId: entryId,
      path: path,
      thumbPath: thumbPath,
      sizeBytes: sizeBytes,
      hash: hash,
    ),
  );

  Future<List<Attachment>> listAttachments(int entryId) =>
      db.attachmentsForEntry(entryId);

  Future<void> deleteAttachment(int id) => db.deleteAttachment(id);
}
