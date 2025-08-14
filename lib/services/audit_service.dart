import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AuditEvent {
  final DateTime ts;
  final String action;
  final String field;
  final dynamic oldValue;
  final dynamic newValue;
  final dynamic key; // measurement.key (Hive)

  AuditEvent({
    required this.ts,
    required this.action,
    required this.field,
    required this.oldValue,
    required this.newValue,
    required this.key,
  });

  Map<String, dynamic> toJson() => {
    'ts': ts.toIso8601String(),
    'action': action,
    'field': field,
    'old': oldValue,
    'new': newValue,
    'key': key,
  };

  static AuditEvent fromJson(Map<String, dynamic> j) => AuditEvent(
    ts: DateTime.tryParse(j['ts'] ?? '') ?? DateTime.now(),
    action: j['action'] ?? '',
    field: j['field'] ?? '',
    oldValue: j['old'],
    newValue: j['new'],
    key: j['key'],
  );
}

class AuditService {
  static Future<File> _logFile() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/reports');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/audit.log');
  }

  static Future<void> append(AuditEvent ev) async {
    final f = await _logFile();
    final sink = f.openWrite(mode: FileMode.append);
    sink.writeln(jsonEncode(ev.toJson()));
    await sink.flush();
    await sink.close();
  }

  static Future<List<AuditEvent>> readAll() async {
    final f = await _logFile();
    if (!await f.exists()) return [];
    final lines = await f.readAsLines();
    return lines.where((l) => l.trim().isNotEmpty).map((l) {
      try {
        return AuditEvent.fromJson(jsonDecode(l));
      } catch (_) {
        return AuditEvent(
          ts: DateTime.now(),
          action: 'parse_error',
          field: '-',
          oldValue: null,
          newValue: l,
          key: null,
        );
      }
    }).toList();
  }

  static Future<void> clear() async {
    final f = await _logFile();
    if (await f.exists()) await f.writeAsString('');
  }
}