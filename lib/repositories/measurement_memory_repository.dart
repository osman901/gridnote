// lib/repositories/local_measurement_repository.dart
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/measurement.dart';
import '../state/measurement_repository.dart';

class LocalMeasurementRepository implements MeasurementRepository {
  LocalMeasurementRepository(this.sheetId);
  final String sheetId;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    final base = Directory('${dir.path}/sheets');
    if (!await base.exists()) await base.create(recursive: true);
    return File('${base.path}/$sheetId.json');
  }

  @override
  Future<List<Measurement>> fetchAll() async {
    try {
      final f = await _file();
      if (!await f.exists()) return const <Measurement>[];
      final text = await f.readAsString();
      if (text.trim().isEmpty) return const <Measurement>[];
      final raw = jsonDecode(text);
      if (raw is! List) return const <Measurement>[];
      return raw
          .map<Measurement>((e) => Measurement.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      return const <Measurement>[];
    }
  }

  Future<void> _atomicWrite(String content) async {
    final f = await _file();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(content, flush: true);
    if (await f.exists()) await f.delete();
    await tmp.rename(f.path);
  }

  @override
  Future<void> saveAll(List<Measurement> items) async {
    int nextId = 0;
    final out = <Measurement>[];
    for (final m in items) {
      final id = m.id ?? nextId++;
      if (id >= nextId) nextId = id + 1;
      out.add(m.copyWith(id: id));
    }
    final jsonList = out.map((e) => e.toJson()).toList(growable: false);
    await _atomicWrite(jsonEncode(jsonList));
  }

  /// Alias requerido por la interfaz; delega en [saveAll].
  @override
  Future<void> saveMany(List<Measurement> items) => saveAll(items);

  @override
  Future<Measurement> add(Measurement item) async {
    final all = await fetchAll();
    final maxId = all.fold<int>(-1, (a, b) => (b.id ?? -1) > a ? (b.id ?? -1) : a);
    final withId = item.copyWith(id: maxId + 1);
    all.add(withId);
    await saveAll(all);
    return withId;
  }

  @override
  Future<Measurement> update(Measurement item) async {
    if (item.id == null) return add(item);
    final all = await fetchAll();
    final idx = all.indexWhere((e) => e.id == item.id);
    if (idx == -1) {
      all.add(item);
    } else {
      all[idx] = item;
    }
    await saveAll(all);
    return item;
  }

  @override
  Future<void> delete(Measurement item) async {
    if (item.id == null) return;
    final all = await fetchAll()..removeWhere((e) => e.id == item.id);
    await saveAll(all);
  }
}
