// lib/services/sheet_registry.dart
import 'package:hive_flutter/hive_flutter.dart';

import '../models/sheet_meta.dart';
import '../models/sheet_meta_hive.dart';

const _kSheetMetaBox = 'sheet_meta_box_v1';

class SheetRegistry {
  SheetRegistry._();
  static final SheetRegistry instance = SheetRegistry._();

  Future<Box<SheetMetaHive>> _box() async {
    final adapter = SheetMetaHiveAdapter();
    if (!Hive.isAdapterRegistered(adapter.typeId)) {
      Hive.registerAdapter(adapter);
    }
    return Hive.isBoxOpen(_kSheetMetaBox)
        ? Hive.box<SheetMetaHive>(_kSheetMetaBox)
        : await Hive.openBox<SheetMetaHive>(_kSheetMetaBox);
  }

  // Mapper dominio <-> hive
  SheetMetaHive _toHive(SheetMeta m) => SheetMetaHive(
    id: m.id,
    name: m.name,
    createdAtUtc: m.createdAt.toUtc(),
    updatedAtUtc: m.updatedAt.toUtc(),
    latitude: m.latitude,
    longitude: m.longitude,
    author: m.author, // <-- NUEVO
  );

  SheetMeta _fromHive(SheetMetaHive h) => SheetMeta(
    id: h.id,
    name: h.name,
    createdAt: h.createdAtUtc,
    updatedAt: h.updatedAtUtc,
    latitude: h.latitude,
    longitude: h.longitude,
    author: h.author, // <-- NUEVO
  );

  Future<List<SheetMeta>> getAll() async {
    final b = await _box();
    return b.values.map(_fromHive).toList(growable: false);
  }

  Future<List<SheetMeta>> getAllSorted() async {
    final list = await getAll();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Future<SheetMeta> create({String? name, String? author}) async {
    final now = DateTime.now().toUtc();
    final id = 'sheet_${now.microsecondsSinceEpoch}';
    final meta = SheetMeta(
      id: id,
      name: name ?? 'Planilla $id',
      createdAt: now,
      updatedAt: now,
      author: author, // <-- NUEVO
    );
    await upsert(meta);
    return meta;
  }

  Future<void> touch(SheetMeta meta) async {
    final b = await _box();
    final now = DateTime.now().toUtc();
    final cur = (await getById(meta.id)) ?? meta;
    final toSave = cur.copyWith(
      name: meta.name,
      updatedAt: now,
      latitude: meta.latitude,
      longitude: meta.longitude,
      author: meta.author, // <-- NUEVO
    );
    await b.put(toSave.id, _toHive(toSave));
  }

  Future<void> upsert(SheetMeta meta) async {
    final b = await _box();
    await b.put(
      meta.id,
      _toHive(meta.copyWith(updatedAt: DateTime.now().toUtc())),
    );
  }

  Future<SheetMeta?> getById(String id) async {
    final b = await _box();
    final h = b.get(id);
    return h == null ? null : _fromHive(h);
  }

  Future<void> removeById(String id) async {
    final b = await _box();
    await b.delete(id);
  }

  Future<void> clear() async {
    final b = await _box();
    await b.clear();
  }
}
