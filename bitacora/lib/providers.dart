// lib/providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/app_db.dart';
import 'services/sheets_repository_drift.dart';

// DB singleton
final dbProvider = Provider<AppDb>((ref) => AppDb());

// Repo (Drift)
final sheetsRepoProvider = Provider<SheetsRepository>((ref) {
  final db = ref.watch(dbProvider);
  return SheetsRepository(db);
});

// Stream reactivo de planillas
final sheetsProvider = StreamProvider((ref) {
  final repo = ref.watch(sheetsRepoProvider);
  return repo.watchSheetsSorted();
});
