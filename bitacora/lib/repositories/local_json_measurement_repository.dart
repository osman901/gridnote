import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/measurement.dart';
import 'measurement_repository.dart';

class LocalJsonMeasurementRepository implements MeasurementRepository {
  LocalJsonMeasurementRepository(this.sheetId);
  final String sheetId;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    final base = Directory('${dir.path}/sheets');
    if (!await base.exists()) await base.create(recursive: true);
    return File('${base.path}/$sheetId.json');
  }

  @override
  Future<List<Measurement>> fetchAll() async {
    final f = await _file();
    if (!await f.exists()) return const <Measurement>[];
    try {
      final raw = jsonDecode(await f.readAsString());
      if (raw is! List) return const <Measurement>[];
      return raw.map<Measurement>((e) => Measurement.fromJson(e as Map<String,dynamic>)).toList();
    } catch (_) { return const <Measurement>[]; }
  }

  Future<void> _write(List<Measurement> items) async {
    int nextId = 0;
    final out = <Measurement>[];
    for (final m in items) {
      final id = m.id ?? nextId++;
      if (id >= nextId) nextId = id + 1;
      out.add(m.copyWith(id: id));
    }
    final f = await _file();
    await f.writeAsString(jsonEncode(out.map((e)=>e.toJson()).toList()), flush: true);
  }

  @override
  Future<void> saveAll(List<Measurement> items) => _write(items);

  @override
  Future<Measurement> add(Measurement item) async {
    final all = await fetchAll();
    final maxId = all.fold<int>(-1, (a,b)=> (b.id ?? -1) > a ? (b.id ?? -1) : a);
    final withId = item.copyWith(id: maxId+1);
    all.add(withId);
    await _write(all);
    return withId;
  }

  @override
  Future<Measurement> update(Measurement item) async {
    if (item.id == null) return add(item);
    final all = await fetchAll();
    final i = all.indexWhere((e)=>e.id==item.id);
    if (i==-1) { all.add(item); } else { all[i]=item; }
    await _write(all);
    return item;
  }

  @override
  Future<void> delete(Measurement item) async {
    if (item.id == null) return;
    final all = await fetchAll()..removeWhere((e)=>e.id==item.id);
    await _write(all);
  }
}
