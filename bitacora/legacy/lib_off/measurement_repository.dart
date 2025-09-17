import 'package:flutter/foundation.dart';
import '../models/measurement.dart';
import '../repositories/measurement_storage.dart' as storage;
import '../repositories/local_measurement_repository.dart';

/// Repo de **estado** para la UI (ChangeNotifier).
class MeasurementRepository extends ChangeNotifier {
  MeasurementRepository({required String sheetId})
      : _storage = LocalMeasurementRepository(sheetId),
        focusKey = ValueNotifier<String?>(null);

  final storage.MeasurementStorage _storage;
  final List<Measurement> _items = <Measurement>[];

  final ValueNotifier<String?> focusKey;

  List<Measurement> get items => List.unmodifiable(_items);

  Future<void> init() async {
    final data = await _storage.fetchAll();
    _items
      ..clear()
      ..addAll(data);
    notifyListeners();
  }

  String keyFor(Measurement m) =>
      '${m.date?.millisecondsSinceEpoch ?? 0}_${m.progresiva.trim()}';

  void clearFocus() => focusKey.value = null;

  Future<void> add(Measurement m) async {
    final saved = await _storage.add(m);
    _items.add(saved);
    notifyListeners();
  }

  Future<void> replace(Measurement original, Measurement updated) async {
    final idx = _indexOf(original);
    if (idx == -1) {
      await add(updated);
      return;
    }
    final saved = await _storage.update(updated);
    _items[idx] = saved;
    notifyListeners();
  }

  Future<void> removeByKey(String key) async {
    final idx = _items.indexWhere((m) => keyFor(m) == key);
    if (idx == -1) return;
    final m = _items[idx];
    await _storage.delete(m);
    _items.removeAt(idx);
    notifyListeners();
  }

  String suggestNextProgresiva() {
    int maxN = 0;
    for (final m in _items) {
      final n = int.tryParse(_digits(m.progresiva));
      if (n != null && n > maxN) maxN = n;
    }
    return (maxN + 1).toString();
  }

  Future<void> saveMany(List<Measurement> items) async {
    await _storage.saveMany(items);
    _items
      ..clear()
      ..addAll(items);
    notifyListeners();
  }

  int _indexOf(Measurement m) {
    if (m.id != null) {
      return _items.indexWhere((e) => e.id == m.id);
    }
    final k = keyFor(m);
    return _items.indexWhere((e) => keyFor(e) == k);
  }

  String _digits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');
}
