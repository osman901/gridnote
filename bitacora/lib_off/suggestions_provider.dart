// lib/state/suggestions_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/app_db.dart';
import '../data/sheets_dao.dart';

final appDbProvider = Provider<AppDb>((ref) => AppDb());
final sheetsDaoProvider = Provider<SheetsDao>((ref) {
  final db = ref.watch(appDbProvider);
  return SheetsDao(db);
});

/// Sugerencias de tÃƒÆ’Ã‚Â­tulos por planilla (ÃƒÆ’Ã‚Âºltimos tÃƒÆ’Ã‚Â­tulos usados)
final titleSuggestionsProvider =
FutureProvider.family<List<String>, int>((ref, sheetId) async {
  final dao = ref.read(sheetsDaoProvider);
  return dao.suggestionsForSheetTitles(sheetId);
});
