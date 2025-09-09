import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local_db.dart';
import '../repositories/sheets_repository.dart';

class SheetPageState {
  final bool loading;
  final List<Entry> entries;
  final String? error;
  const SheetPageState({this.loading = true, this.entries = const [], this.error});

  SheetPageState copyWith({bool? loading, List<Entry>? entries, String? error}) =>
      SheetPageState(
        loading: loading ?? this.loading,
        entries: entries ?? this.entries,
        error: error,
      );
}

class SheetPageController extends StateNotifier<SheetPageState> {
  SheetPageController(this._repo, this.sheetId) : super(const SheetPageState());
  final SheetsRepository _repo;
  final int sheetId;

  Future<void> load() async {
    try {
      final list = await _repo.rows(sheetId);
      state = state.copyWith(loading: false, entries: list, error: null);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> addRow() async {
    try {
      final e = await _repo.addRow(sheetId);
      state = state.copyWith(entries: [e, ...state.entries]);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> saveRow(Entry e) async {
    try {
      await _repo.saveRow(e);
      final idx = state.entries.indexWhere((x) => x.id == e.id);
      if (idx >= 0) {
        final copy = [...state.entries];
        copy[idx] = e;
        state = state.copyWith(entries: copy);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteRow(int id) async {
    try {
      await _repo.db.deleteEntry(id);
      state = state.copyWith(entries: state.entries.where((x) => x.id != id).toList());
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<String> persistImage(File src, {required int entryId}) =>
      _repo.persistImage(src, sheetId: sheetId, entryId: entryId);
}

// Providers
final _dbProvider = Provider<LocalDB>((_) => LocalDB());
final sheetsRepoProvider =
Provider<SheetsRepository>((ref) => SheetsRepository(ref.read(_dbProvider)));

final sheetPageControllerProvider = StateNotifierProvider.family<SheetPageController, SheetPageState, int>((ref, sheetId) {
  return SheetPageController(ref.read(sheetsRepoProvider), sheetId)..load();
});
