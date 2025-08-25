// lib/state/measurement_async_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/measurement.dart';
import '../widgets/measurement_columns.dart';
import 'measurement_repository.dart';
import '../repositories/local_measurement_repository.dart';
// Si querés usar el repo encriptado, cambiá la línea de arriba por:
// import '../repositories/encrypted_local_measurement_repository.dart';

/// Repositorio por planilla (LOCAL)
final measurementRepoProvider =
Provider.family<MeasurementRepository, String>((ref, sheetId) {
  return LocalMeasurementRepository(sheetId);
  // return EncryptedLocalMeasurementRepository(sheetId); // <- alternativo
});

/// Contador de operaciones en vuelo (guardar, etc.)
final _inFlightOpsProvider = StateProvider<int>((_) => 0);
final isSavingProvider =
Provider<bool>((ref) => ref.watch(_inFlightOpsProvider) > 0);

/// Texto de búsqueda por planilla
final searchQueryProvider =
StateProvider.family<String, String>((_, __) => '');

/// Async principal POR planilla
final measurementAsyncProvider = AsyncNotifierProvider.family<
    MeasurementAsyncNotifier, List<Measurement>, String>(
  MeasurementAsyncNotifier.new,
);

/// Lista filtrada POR planilla (según `searchQueryProvider`)
final measurementFilteredAsyncProvider =
Provider.family<AsyncValue<List<Measurement>>, String>((ref, sheetId) {
  final asyncList = ref.watch(measurementAsyncProvider(sheetId));
  final q = ref.watch(searchQueryProvider(sheetId)).trim().toLowerCase();
  return asyncList.whenData((list) {
    if (q.isEmpty) return list;
    return list.where((m) {
      final p = m.progresiva.toLowerCase();
      final o = (m.observations ?? '').toLowerCase();
      return p.contains(q) || o.contains(q);
    }).toList(growable: false);
  });
});

class MeasurementAsyncNotifier
    extends FamilyAsyncNotifier<List<Measurement>, String> {
  MeasurementRepository get _repo => ref.read(measurementRepoProvider(arg));

  final List<EditCommand> _undo = [];
  final List<EditCommand> _redo = [];
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  @override
  Future<List<Measurement>> build(String sheetId) => _repo.fetchAll();

  Future<void> reload() async {
    final list = await _repo.fetchAll();
    state = AsyncData(list);
  }

  int _findIndex(Measurement m, List<Measurement> list) {
    if (m.id != null) return list.indexWhere((e) => e.id == m.id);
    return list.indexWhere((e) =>
    e.progresiva == m.progresiva &&
        e.date.year == m.date.year &&
        e.date.month == m.date.month &&
        e.date.day == m.date.day);
  }

  Future<void> _executeOptimisticAndPersist(EditCommand cmd,
      {bool pushToUndo = true}) async {
    final before = state;
    final prevList = before.value ?? const <Measurement>[];

    final optimistic = cmd.execute(prevList);
    state = AsyncData(optimistic);
    if (pushToUndo) {
      _undo.add(cmd);
      _redo.clear();
    }

    ref.read(_inFlightOpsProvider.notifier).state++;
    try {
      final reconciled = await cmd.save(_repo, optimistic);
      if (!identical(reconciled, optimistic)) state = AsyncData(reconciled);
    } catch (e, st) {
      final reverted = cmd.unexecute(optimistic);
      state = AsyncData(reverted);
      if (pushToUndo && _undo.isNotEmpty && identical(_undo.last, cmd)) {
        _undo.removeLast();
      }
      state = AsyncError(e, st);
      state = before;
      rethrow;
    } finally {
      ref.read(_inFlightOpsProvider.notifier).state--;
    }
  }

  Future<void> setAll(List<Measurement> items) async {
    await _executeOptimisticAndPersist(
      SetAllCommand(state.value ?? const [], List.of(items)),
    );
  }

  Future<void> add(Measurement m, {int? at}) async {
    final idx = at ?? (state.value?.length ?? 0);
    await _executeOptimisticAndPersist(AddRowCommand(m, idx));
  }

  Future<void> duplicateRow(Measurement m) async {
    final list = state.value ?? const [];
    final idx = _findIndex(m, list);
    if (idx == -1) return;
    await add(m, at: idx + 1);
  }

  Future<void> deleteRow(Measurement m) async {
    final list = state.value ?? const [];
    final idx = _findIndex(m, list);
    if (idx == -1) return;
    await _executeOptimisticAndPersist(DeleteRowCommand(m, idx));
  }

  Future<void> updateRow(Measurement updated) async {
    final list = state.value ?? const [];
    final idx = _findIndex(updated, list);
    if (idx == -1) return;
    final old = list[idx];
    await _executeOptimisticAndPersist(UpdateRowCommand(old, updated, idx));
  }

  Future<void> sortBy(String column, {bool asc = true}) async {
    int cmpNum(num? a, num? b) {
      if (a == null && b == null) return 0;
      if (a == null) return -1;
      if (b == null) return 1;
      return a.compareTo(b);
    }
    final prev = List<Measurement>.from(state.value ?? const []);
    final next = List<Measurement>.from(prev);
    next.sort((a, b) {
      int r = 0;
      switch (column) {
        case MeasurementColumn.progresiva:
          r = a.progresiva.compareTo(b.progresiva);
          break;
        case MeasurementColumn.ohm1m:
          r = cmpNum(a.ohm1m, b.ohm1m);
          break;
        case MeasurementColumn.ohm3m:
          r = cmpNum(a.ohm3m, b.ohm3m);
          break;
        case MeasurementColumn.observations:
          r = (a.observations ?? '').compareTo(b.observations ?? '');
          break;
        case MeasurementColumn.date:
          r = a.date.compareTo(b.date);
          break;
      }
      return asc ? r : -r;
    });
    await _executeOptimisticAndPersist(SortCommand(prev, next));
  }

  Future<void> undo() async {
    if (_undo.isEmpty) return;
    final cmd = _undo.removeLast();
    final before = state;
    final cur = before.value ?? const <Measurement>[];
    final optimistic = cmd.unexecute(cur);
    state = AsyncData(optimistic);
    _redo.add(cmd);

    ref.read(_inFlightOpsProvider.notifier).state++;
    try {
      final reconciled = await cmd.unsave(_repo, optimistic);
      if (!identical(reconciled, optimistic)) state = AsyncData(reconciled);
    } catch (e, st) {
      final revert = cmd.execute(optimistic);
      state = AsyncData(revert);
      _redo.removeLast();
      _undo.add(cmd);
      state = AsyncError(e, st);
      state = before;
      rethrow;
    } finally {
      ref.read(_inFlightOpsProvider.notifier).state--;
    }
  }

  Future<void> redo() async {
    if (_redo.isEmpty) return;
    final cmd = _redo.removeLast();
    final before = state;
    final cur = before.value ?? const <Measurement>[];
    final optimistic = cmd.execute(cur);
    state = AsyncData(optimistic);
    _undo.add(cmd);

    ref.read(_inFlightOpsProvider.notifier).state++;
    try {
      final reconciled = await cmd.save(_repo, optimistic);
      if (!identical(reconciled, optimistic)) state = AsyncData(reconciled);
    } catch (e, st) {
      final revert = cmd.unexecute(optimistic);
      state = AsyncData(revert);
      _undo.removeLast();
      _redo.add(cmd);
      state = AsyncError(e, st);
      state = before;
      rethrow;
    } finally {
      ref.read(_inFlightOpsProvider.notifier).state--;
    }
  }
}

/// ----- Commands -----
abstract class EditCommand {
  List<Measurement> execute(List<Measurement> list);
  List<Measurement> unexecute(List<Measurement> list);

  Future<List<Measurement>> save(
      MeasurementRepository repo, List<Measurement> optimistic);
  Future<List<Measurement>> unsave(
      MeasurementRepository repo, List<Measurement> optimistic);
}

class SetAllCommand extends EditCommand {
  SetAllCommand(this.prev, this.next);
  final List<Measurement> prev;
  final List<Measurement> next;

  @override
  List<Measurement> execute(List<Measurement> list) => List.of(next);
  @override
  List<Measurement> unexecute(List<Measurement> list) => List.of(prev);

  @override
  Future<List<Measurement>> save(
      MeasurementRepository repo, List<Measurement> optimistic) async {
    await repo.saveMany(optimistic);
    return optimistic;
  }

  @override
  Future<List<Measurement>> unsave(
      MeasurementRepository repo, List<Measurement> optimistic) async {
    await repo.saveMany(prev);
    return prev;
  }
}

class AddRowCommand extends EditCommand {
  AddRowCommand(this.item, this.index);
  final Measurement item;
  final int index;

  @override
  List<Measurement> execute(List<Measurement> list) {
    final next = List<Measurement>.from(list);
    next.insert(index, item);
    return next;
  }

  @override
  List<Measurement> unexecute(List<Measurement> list) {
    final next = List<Measurement>.from(list);
    next.removeAt(index);
    return next;
  }

  @override
  Future<List<Measurement>> save(
      MeasurementRepository repo, List<Measurement> optimistic) async {
    await repo.saveMany(optimistic);
    return optimistic;
  }

  @override
  Future<List<Measurement>> unsave(
      MeasurementRepository repo, List<Measurement> optimistic) async {
    final prev = List<Measurement>.from(optimistic)..removeAt(index);
    await repo.saveMany(prev);
    return prev;
  }
}

class DeleteRowCommand extends EditCommand {
  DeleteRowCommand(this.item, this.index);
  final Measurement item;
  final int index;

  @override
  List<Measurement> execute(List<Measurement> list) {
    final next = List<Measurement>.from(list);
    next.removeAt(index);
    return next;
  }

  @override
  List<Measurement> unexecute(List<Measurement> list) {
    final next = List<Measurement>.from(list);
    next.insert(index, item);
    return next;
  }

  @override
  Future<List<Measurement>> save(
      MeasurementRepository repo, List<Measurement> optimistic) async {
    await repo.saveMany(optimistic);
    return optimistic;
  }

  @override
  Future<List<Measurement>> unsave(
      MeasurementRepository repo, List<Measurement> optimistic) async {
    final prev = List<Measurement>.from(optimistic)..insert(index, item);
    await repo.saveMany(prev);
    return prev;
  }
}

class UpdateRowCommand extends EditCommand {
  UpdateRowCommand(this.oldItem, this.newItem, this.index);
  final Measurement oldItem;
  final Measurement newItem;
  final int index;

  @override
  List<Measurement> execute(List<Measurement> list) {
    final next = List<Measurement>.from(list);
    next[index] = newItem;
    return next;
  }

  @override
  List<Measurement> unexecute(List<Measurement> list) {
    final next = List<Measurement>.from(list);
    next[index] = oldItem;
    return next;
  }

  @override
  Future<List<Measurement>> save(
      MeasurementRepository repo, List<Measurement> optimistic) async {
    await repo.saveMany(optimistic);
    return optimistic;
  }

  @override
  Future<List<Measurement>> unsave(
      MeasurementRepository repo, List<Measurement> optimistic) async {
    final prev = List<Measurement>.from(optimistic);
    prev[index] = oldItem;
    await repo.saveMany(prev);
    return prev;
  }
}

class SortCommand extends EditCommand {
  SortCommand(this.prev, this.next);
  final List<Measurement> prev;
  final List<Measurement> next;

  @override
  List<Measurement> execute(List<Measurement> list) => List.of(next);
  @override
  List<Measurement> unexecute(List<Measurement> list) => List.of(prev);

  @override
  Future<List<Measurement>> save(
      MeasurementRepository repo, List<Measurement> optimistic) async {
    await repo.saveMany(optimistic);
    return optimistic;
  }

  @override
  Future<List<Measurement>> unsave(
      MeasurementRepository repo, List<Measurement> optimistic) async {
    await repo.saveMany(prev);
    return prev;
  }
}
