import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sheet_meta.dart';

class SheetsStore extends ChangeNotifier {
  static const _kKey = 'gridnote_sheets_meta';
  final List<SheetMeta> _all = [];

  List<SheetMeta> get all => List.unmodifiable(_all);

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString(_kKey);
    _all.clear();
    if (s != null && s.isNotEmpty) {
      _all.addAll(SheetMeta.decodeList(s));
    } else {
      // Semilla demo si está vacío
      _all.addAll([
        SheetMeta(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: 'Planilla 1'),
        SheetMeta(
            id: (DateTime.now().millisecondsSinceEpoch + 109).toString(),
            name: 'rrr'),
      ]);
      await _persist();
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kKey, SheetMeta.encodeList(_all));
  }

  SheetMeta? byId(String id) => _all.firstWhere((e) => e.id == id,
      orElse: () => SheetMeta(id: id, name: 'Planilla'));

  Future<void> rename(String id, String name) async {
    final i = _all.indexWhere((e) => e.id == id);
    if (i == -1) return;
    _all[i] = _all[i].copyWith(name: name);
    await _persist();
    notifyListeners();
  }

  Future<String> addNew([String name = 'Nueva planilla']) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _all.insert(0, SheetMeta(id: id, name: name));
    await _persist();
    notifyListeners();
    return id;
  }

  Future<void> setLocation(String id, {double? lat, double? lng}) async {
    final i = _all.indexWhere((e) => e.id == id);
    if (i == -1) return;
    _all[i] = _all[i].copyWith(latitude: lat, longitude: lng);
    await _persist();
    notifyListeners();
  }
}
