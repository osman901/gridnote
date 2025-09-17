// lib/providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/local_db.dart';
import 'repositories/sheets_repo.dart';

// Repositorio principal (usa LocalDb + SheetsRepo)
final sheetsRepoProvider = Provider<SheetsRepo>((ref) {
  final db = LocalDb();
  return SheetsRepo(db);
});

// ---- Sheets ----
final sheetsProvider = FutureProvider<List<Sheet>>((ref) {
  final repo = ref.watch(sheetsRepoProvider);
  return repo.listSheets();
});

final sheetByIdProvider = FutureProvider.family<Sheet?, int>((ref, id) {
  final repo = ref.watch(sheetsRepoProvider);
  return repo.getSheet(id);
});

// ---- Entries ----
final entriesProvider = FutureProvider.family<List<Entry>, int>((ref, sheetId) {
  final repo = ref.watch(sheetsRepoProvider);
  return repo.listEntries(sheetId);
});

// ---- Attachments ----
final attachmentsProvider =
FutureProvider.family<List<Attachment>, int>((ref, entryId) {
  final repo = ref.watch(sheetsRepoProvider);
  return repo.listAttachments(entryId);
});

// ---- Sugerencias de títulos para autocompletar (UI) ----
final suggestionsProvider = Provider<List<String>>((ref) => const [
  'Inspección',
  'Muestreo',
  'Observación',
  'Reparación',
  'Chequeo',
]);
