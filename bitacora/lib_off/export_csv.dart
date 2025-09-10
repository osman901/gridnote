// lib/export/export_csv.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/free_sheet.dart';

String _csvEscape(String s) {
  final needsQuotes = s.contains(',') || s.contains('\n') || s.contains('"');
  var out = s.replaceAll('"', '""');
  return needsQuotes ? '"$out"' : out;
}

Future<File> exportFreeSheetToCsv(FreeSheetData data, {String? filename}) async {
  final buf = StringBuffer();
  // headers
  buf.writeln(data.headers.map(_csvEscape).join(','));
  // rows
  for (final row in data.rows) {
    final copy = List<String>.from(row);
    if (copy.length < data.headers.length) {
      copy.addAll(List.filled(data.headers.length - copy.length, ''));
    } else if (copy.length > data.headers.length) {
      copy.removeRange(data.headers.length, copy.length);
    }
    buf.writeln(copy.map(_csvEscape).join(','));
  }
  final dir = await getTemporaryDirectory();
  final name = (filename ?? '${data.name}.csv').replaceAll(' ', '_');
  final file = File('${dir.path}/$name');
  return file.writeAsString(buf.toString(), flush: true);
}
