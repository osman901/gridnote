// lib/services/measurements_store.dart
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/measurement.dart';

class MeasurementsSnapshot {
  MeasurementsSnapshot({
    required this.headers,
    required this.items,
    required this.updatedAt,
  });

  final List<String> headers;
  final List<Measurement> items;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'headers': headers,
    'items': items.map((e) => e.toJson()).toList(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory MeasurementsSnapshot.fromJson(Map<String, dynamic> j) {
    final hdr = (j['headers'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
    final raw = (j['items'] as List?) ?? const <dynamic>[];
    final it = raw
        .whereType<Map<String, dynamic>>()
        .map(Measurement.fromJson)
        .toList(growable: false);
    final ts = DateTime.tryParse((j['updatedAt'] ?? '').toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return MeasurementsSnapshot(headers: hdr, items: it, updatedAt: ts);
  }

  static MeasurementsSnapshot empty() => MeasurementsSnapshot(
    headers: const <String>[],
    items: const <Measurement>[],
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );
}

class MeasurementsStore {
  MeasurementsStore._();
  static final MeasurementsStore instance = MeasurementsStore._();

  Future<Directory> _baseDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'sheets_data'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _fileFor(String sheetId) async {
    final dir = await _baseDir();
    return File(p.join(dir.path, '$sheetId.json'));
  }

  /// Carga headers + filas de una planilla. Si no existe, devuelve vacÃƒÆ’Ã‚Â­o.
  Future<MeasurementsSnapshot> load(String sheetId) async {
    try {
      final f = await _fileFor(sheetId);
      if (!await f.exists()) return MeasurementsSnapshot.empty();
      final txt = await f.readAsString();
      final map = jsonDecode(txt) as Map<String, dynamic>;
      return MeasurementsSnapshot.fromJson(map);
    } catch (_) {
      return MeasurementsSnapshot.empty();
    }
  }

  /// Guarda headers + filas (sobrescribe el archivo).
  Future<void> save(String sheetId, MeasurementsSnapshot snap) async {
    final f = await _fileFor(sheetId);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(snap.toJson()), flush: true);
    // swap atÃƒÆ’Ã‚Â³mico sencillo
    if (await f.exists()) await f.delete();
    await tmp.rename(f.path);
  }
}
