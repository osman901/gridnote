// lib/export/export_excel.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/free_sheet.dart';

Future<File> exportFreeSheetToXlsLike(FreeSheetData data, {String? filename}) async {
  final buf = StringBuffer()
    ..writeln('<!DOCTYPE html>')
    ..writeln('<html lang="es"><head><meta charset="utf-8">')
    ..writeln('<meta http-equiv="X-UA-Compatible" content="IE=edge">')
    ..writeln('<style>table{border-collapse:collapse}th,td{border:1px solid #000;padding:4px}</style>')
    ..writeln('</head><body><table>');

  // headers
  buf.write('<tr>');
  for (final h in data.headers) {
    buf.write('<th>${_html(h)}</th>');
  }
  buf.writeln('</tr>');

  // rows
  for (final row in data.rows) {
    buf.write('<tr>');
    final copy = List<String?>.from(row)..length = data.headers.length;
    for (final c in copy) {
      buf.write('<td>${_html(c ?? '')}</td>');
    }
    buf.writeln('</tr>');
  }

  buf.writeln('</table></body></html>');

  final dir = await getTemporaryDirectory();
  final safeName = (filename ?? '${data.name}.xls')
      .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
      .replaceAll(' ', '_');
  final file = File('${dir.path}/$safeName');
  return file.writeAsString(buf.toString(), flush: true);
}

String _html(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
