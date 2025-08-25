// lib/repositories/encrypted_local_measurement_repository.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../models/measurement.dart';
import '../state/measurement_repository.dart';
import '../services/secure_store.dart';
import '../services/autosave_service.dart';
import '../services/error_reporter.dart';

class EncryptedLocalMeasurementRepository implements MeasurementRepository {
  EncryptedLocalMeasurementRepository(this.sheetId);
  final String sheetId;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    final base = Directory('${dir.path}/sheets');
    if (!await base.exists()) await base.create(recursive: true);
    return File('${base.path}/$sheetId.jsonc');
  }

  @override
  Future<List<Measurement>> fetchAll() async {
    final f = await _file();
    try {
      // preferir autosave si es más nuevo
      final mainExists = await f.exists();
      final mainMtime = mainExists ? await f.lastModified() : null;
      final autoMtime = await AutosaveService.mtime(sheetId);

      if (autoMtime != null && (mainMtime == null || autoMtime.isAfter(mainMtime))) {
        final rec = await AutosaveService.tryRead(sheetId);
        if (rec != null) return rec;
      }

      final dec = await SecureStore.instance.readDecryptedFile(f);
      if (dec == null) return const <Measurement>[];
      final raw = jsonDecode(utf8.decode(dec));
      if (raw is! List) return const <Measurement>[];
      return raw
          .map<Measurement>((e) => Measurement.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } catch (e, st) {
      await ErrorReport.I.recordError(e, st, hint: 'fetchAll', extra: {'sheetId': sheetId});
      try {
        if (await f.exists()) {
          await f.rename('${f.path}.corrupt');
        }
      } catch (_) {}
      final rec = await AutosaveService.tryRead(sheetId);
      return rec ?? const <Measurement>[];
    }
  }

  Future<void> _saveList(List<Measurement> items, {bool clearAutosave = true}) async {
    int nextId = 0;
    final out = <Measurement>[];
    for (final m in items) {
      final id = m.id ?? nextId++;
      if (id >= nextId) nextId = id + 1;
      out.add(m.copyWith(id: id));
    }
    final bytes = Uint8List.fromList(
      utf8.encode(jsonEncode(out.map((e) => e.toJson()).toList())),
    );
    final f = await _file();
    await SecureStore.instance.writeEncryptedFile(f, bytes);
    if (clearAutosave) await AutosaveService.clear(sheetId);
  }

  @override
  Future<void> saveAll(List<Measurement> items) => _saveList(items);

  // ✅ implementa el requerido por la interfaz
  @override
  Future<void> saveMany(List<Measurement> items) => _saveList(items);

  @override
  Future<Measurement> add(Measurement item) async {
    final all = await fetchAll();
    final maxId =
    all.fold<int>(-1, (a, b) => (b.id ?? -1) > a ? (b.id ?? -1) : a);
    final withId = item.copyWith(id: maxId + 1);
    all.add(withId);
    await _saveList(all);
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
    await _saveList(all);
    return item;
  }

  @override
  Future<void> delete(Measurement item) async {
    if (item.id == null) return;
    final all = await fetchAll()..removeWhere((e) => e.id == item.id);
    await _saveList(all);
  }
}
