// lib/services/sheets_store.dart
import 'dart:convert';
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
      _all.addAll(_decodeList(s));
    } else {
      final now = DateTime.now().toUtc();
      _all.addAll([
        SheetMeta(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: 'Planilla 1',
          createdAt: now,
          updatedAt: now,
        ),
        SheetMeta(
          id: (DateTime.now().millisecondsSinceEpoch + 109).toString(),
          name: 'rrr',
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      await _persist();
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kKey, _encodeList(_all));
  }

  SheetMeta byId(String id) {
    final found = _all.where((e) => e.id == id);
    if (found.isNotEmpty) return found.first;
    final now = DateTime.now().toUtc();
    return SheetMeta(id: id, name: 'Planilla', createdAt: now, updatedAt: now);
  }

  Future<void> rename(String id, String name) async {
    final i = _all.indexWhere((e) => e.id == id);
    if (i == -1) return;
    _all[i] = _all[i].copyWith(name: name, updatedAt: DateTime.now().toUtc());
    await _persist();
    notifyListeners();
  }

  Future<String> addNew([String name = 'Nueva planilla']) async {
    final now = DateTime.now().toUtc();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _all.insert(0, SheetMeta(id: id, name: name, createdAt: now, updatedAt: now));
    await _persist();
    notifyListeners();
    return id;
  }

  Future<void> setLocation(String id, {double? lat, double? lng}) async {
    final i = _all.indexWhere((e) => e.id == id);
    if (i == -1) return;
    _all[i] = _all[i].copyWith(
      latitude: lat,
      longitude: lng,
      updatedAt: DateTime.now().toUtc(),
    );
    await _persist();
    notifyListeners();
  }

  // ---------- JSON helpers ----------
  String _encodeList(List<SheetMeta> list) =>
      jsonEncode(list.map(_toJson).toList());

  List<SheetMeta> _decodeList(String s) {
    final raw = jsonDecode(s);
    if (raw is! List) return <SheetMeta>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(_fromJson)
        .toList(growable: false);
  }

  Map<String, dynamic> _toJson(SheetMeta m) => {
    'id': m.id,
    'name': m.name,
    'createdAt': m.createdAt.toUtc().toIso8601String(),
    'updatedAt': m.updatedAt.toUtc().toIso8601String(),
    'latitude': m.latitude,
    'longitude': m.longitude,
  };

  SheetMeta _fromJson(Map<String, dynamic> j) {
    final createdAt = DateTime.tryParse('${j['createdAt']}')?.toUtc() ??
        DateTime.now().toUtc();
    final updatedAt =
        DateTime.tryParse('${j['updatedAt']}')?.toUtc() ?? createdAt;
    return SheetMeta(
      id: '${j['id']}',
      name: '${j['name'] ?? 'Planilla'}',
      createdAt: createdAt,
      updatedAt: updatedAt,
      latitude: (j['latitude'] as num?)?.toDouble(),
      longitude: (j['longitude'] as num?)?.toDouble(),
    );
  }
}
