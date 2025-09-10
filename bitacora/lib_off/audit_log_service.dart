import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AuditLogService {
  AuditLogService(this.sheetId);
  final String sheetId;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/gridnote_audit_$sheetId.log');
  }

  Future<void> log(String action, Map<String, Object?> details) async {
    final f = await _file();
    final line = jsonEncode({
      'ts': DateTime.now().toIso8601String(),
      'action': action,
      'details': details,
    });
    await f.writeAsString('$line\n', mode: FileMode.append, flush: true);
  }
}
