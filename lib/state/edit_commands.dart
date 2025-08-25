// lib/state/edit_commands.dart
import '../models/measurement.dart';
import 'measurement_repository.dart';

abstract class EditCommand {
  List<Measurement> execute(List<Measurement> current);
  List<Measurement> unexecute(List<Measurement> current);

  /// Persiste el cambio y devuelve una lista "reconciliada" (p.ej. con IDs del server).
  Future<List<Measurement>> save(MeasurementRepository repo, List<Measurement> optimistic);

  /// Revierte en persistencia y devuelve la lista reconciliada tras revertir.
  Future<List<Measurement>> unsave(MeasurementRepository repo, List<Measurement> optimistic);
}

/// Reemplaza toda la lista (útil para import masivo).
class SetAllCommand implements EditCommand {
  SetAllCommand(this._prev, this._next);
  final List<Measurement> _prev;
  final List<Measurement> _next;

  @override
  List<Measurement> execute(List<Measurement> current) => List<Measurement>.from(_next);

  @override
  List<Measurement> unexecute(List<Measurement> current) => List<Measurement>.from(_prev);

  @override
  Future<List<Measurement>> save(MeasurementRepository repo, List<Measurement> optimistic) async {
    await repo.saveAll(optimistic); // <-- cambiado
    return List<Measurement>.from(optimistic);
  }

  @override
  Future<List<Measurement>> unsave(MeasurementRepository repo, List<Measurement> optimistic) async {
    await repo.saveAll(_prev); // <-- cambiado
    return List<Measurement>.from(_prev);
  }
}

class AddRowCommand implements EditCommand {
  AddRowCommand(this.item, this.index);
  final Measurement item;
  final int index;

  // Versión persistida (con ID) para soportar undo() -> unsave()
  Measurement? _persisted;

  @override
  List<Measurement> execute(List<Measurement> current) {
    final list = List<Measurement>.from(current);
    final i = index.clamp(0, list.length);
    list.insert(i, item);
    return list;
  }

  @override
  List<Measurement> unexecute(List<Measurement> current) {
    if (current.isEmpty) return List<Measurement>.from(current);
    final list = List<Measurement>.from(current);
    final i = index.clamp(0, list.length - 1);
    if (i >= 0 && i < list.length) list.removeAt(i);
    return list;
  }

  @override
  Future<List<Measurement>> save(MeasurementRepository repo, List<Measurement> optimistic) async {
    final saved = await repo.add(item);
    _persisted = saved;
    final list = List<Measurement>.from(optimistic);
    final i = index.clamp(0, list.length - 1);
    if (list.isEmpty) {
      return [saved];
    }
    list[i] = saved; // reemplaza versión sin ID por la persistida
    return list;
  }

  @override
  Future<List<Measurement>> unsave(MeasurementRepository repo, List<Measurement> optimistic) async {
    // En undo() ya quitaste el item de la lista; solo borra en backend.
    await repo.delete(_persisted ?? item);
    return List<Measurement>.from(optimistic);
  }
}

class DeleteRowCommand implements EditCommand {
  DeleteRowCommand(this.item, this.index);
  final Measurement item;
  final int index;

  @override
  List<Measurement> execute(List<Measurement> current) {
    final list = List<Measurement>.from(current);
    if (index >= 0 && index < list.length) list.removeAt(index);
    return list;
  }

  @override
  List<Measurement> unexecute(List<Measurement> current) {
    final list = List<Measurement>.from(current);
    final i = index.clamp(0, list.length);
    list.insert(i, item);
    return list;
  }

  @override
  Future<List<Measurement>> save(MeasurementRepository repo, List<Measurement> optimistic) async {
    await repo.delete(item);
    return List<Measurement>.from(optimistic);
  }

  @override
  Future<List<Measurement>> unsave(MeasurementRepository repo, List<Measurement> optimistic) async {
    // Reponer el item eliminado. add() puede devolverlo con ID distinto.
    final restored = await repo.add(item);
    final list = List<Measurement>.from(optimistic);
    final i = index.clamp(0, list.length);
    list.insert(i, restored);
    return list;
  }
}

class UpdateRowCommand implements EditCommand {
  UpdateRowCommand(this.oldMeasurement, this.newMeasurement, this.index);
  final Measurement oldMeasurement;
  final Measurement newMeasurement;
  final int index;

  @override
  List<Measurement> execute(List<Measurement> current) {
    final list = List<Measurement>.from(current);
    if (index >= 0 && index < list.length) list[index] = newMeasurement;
    return list;
  }

  @override
  List<Measurement> unexecute(List<Measurement> current) {
    final list = List<Measurement>.from(current);
    if (index >= 0 && index < list.length) list[index] = oldMeasurement;
    return list;
  }

  @override
  Future<List<Measurement>> save(MeasurementRepository repo, List<Measurement> optimistic) async {
    final saved = await repo.update(newMeasurement);
    final list = List<Measurement>.from(optimistic);
    if (index >= 0 && index < list.length) list[index] = saved;
    return list;
  }

  @override
  Future<List<Measurement>> unsave(MeasurementRepository repo, List<Measurement> optimistic) async {
    final restored = await repo.update(oldMeasurement);
    final list = List<Measurement>.from(optimistic);
    if (index >= 0 && index < list.length) list[index] = restored;
    return list;
  }
}

/// Ordenación con memoria del orden previo para deshacer.
class SortCommand implements EditCommand {
  SortCommand(this._prevOrder, this._nextOrder);
  final List<Measurement> _prevOrder;
  final List<Measurement> _nextOrder;

  @override
  List<Measurement> execute(List<Measurement> current) => List<Measurement>.from(_nextOrder);

  @override
  List<Measurement> unexecute(List<Measurement> current) => List<Measurement>.from(_prevOrder);

  @override
  Future<List<Measurement>> save(MeasurementRepository repo, List<Measurement> optimistic) async {
    await repo.saveAll(optimistic); // <-- cambiado
    return List<Measurement>.from(optimistic);
  }

  @override
  Future<List<Measurement>> unsave(MeasurementRepository repo, List<Measurement> optimistic) async {
    await repo.saveAll(_prevOrder); // <-- cambiado
    return List<Measurement>.from(_prevOrder);
  }
}
