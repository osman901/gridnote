// lib/state/measurement_repository.dart
import 'dart:collection';
import 'package:flutter/foundation.dart';

import '../models/measurement.dart';
import '../services/storage_manager.dart';

/// Fuente única de la verdad para mediciones **por planilla**.
class MeasurementRepository extends ChangeNotifier {
  MeasurementRepository(this.sheetId);

  /// ID de planilla (sheet) al que pertenece este repo.
  final String sheetId;

  final List<Measurement> _items = <Measurement>[];
  UnmodifiableListView<Measurement> get items => UnmodifiableListView(_items);

  final ValueNotifier<String?> focusKey = ValueNotifier<String?>(null);

  bool _inited = false;

  Future<void> init() async {
    if (_inited) return;
    try {
      final loaded = await StorageManager.instance.loadAll(sheetId);
      _items
        ..clear()
        ..addAll(loaded);
    } catch (_) {
      // si falla la carga, queda vacío (offline-first)
    }
    _inited = true;
    notifyListeners();
  }

  String keyFor(Measurement m) =>
      '${m.id ?? ''}|${m.progresiva}|${m.date.millisecondsSinceEpoch}';

  Future<void> _persist() async {
    try {
      await StorageManager.instance.saveAll(sheetId, _items);
    } catch (_) {}
  }

  Future<void> add(Measurement m) async {
    _items.add(m);
    notifyListeners();
    await _persist();
  }

  Future<void> replace(Measurement oldM, Measurement newM) async {
    final key = keyFor(oldM);
    final idx = _items.indexWhere((e) => keyFor(e) == key);
    if (idx < 0) return;
    _items[idx] = newM;
    notifyListeners();
    await _persist();
  }

  Future<void> removeByKey(String key) async {
    _items.removeWhere((e) => keyFor(e) == key);
    notifyListeners();
    await _persist();
  }

  /// Sugerencia simple para progresiva: "PK 10+100" -> "PK 10+200"
  String suggestNextProgresiva() {
    for (var i = _items.length - 1; i >= 0; i--) {
      final p = _items[i].progresiva.trim();
      if (p.isEmpty) continue;
      final re = RegExp(r'^(PK\s*)(\d+)\+(\d+)$', caseSensitive: false);
      final m = re.firstMatch(p);
      if (m == null) return p;
      final pref = m.group(1)!;
      final km = int.parse(m.group(2)!);
      final plus = int.parse(m.group(3)!);
      final next = plus + 100;
      return '$pref$km+${next.toString().padLeft(3, '0')}';
    }
    return '';
  }

  void requestFocusByKey(String key) => focusKey.value = key;
  void clearFocus() => focusKey.value = null;
}
