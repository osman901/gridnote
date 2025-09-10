// lib/export/excel_exporter.dart
import 'dart:io';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' hide Column;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/local_db.dart';
import '../repositories/sheets_repo.dart';

class ExcelExporter {
  ExcelExporter(this.repo);
  final SheetsRepo repo;

  Future<File> exportSheet(Sheet sheet) async {
    final book = Workbook();
    final ws = book.worksheets[0];
    ws.name = sheet.name;

    // Encabezados según tu esquema actual
    final headers = <String>[
      'Nota',
      'Lat',
      'Lng',
      'Foto (ruta)',
      'Actualizado',
    ];
    for (var i = 0; i < headers.length; i++) {
      final cell = ws.getRangeByIndex(1, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle.bold = true;
    }

    final rows = await repo.listEntries(sheet.id);

    int r = 2;
    for (final e in rows) {
      // Tu Entry tiene: note, lat, lng (o lon), photoPath, updatedAt
      final note = e.note ?? '';

      final lat = e.lat;
      // soporta esquemas que usen `lng` o `lon`
      final dyn = e as dynamic;
      final double? lng = (dyn.lng is double?) ? dyn.lng : (dyn.lon as double?);

      final photo = (e as dynamic).photoPath as String?;
      final updated = _formatTs((e as dynamic).updatedAt);

      ws.getRangeByIndex(r, 1).setText(note);
      ws.getRangeByIndex(r, 2).setNumber(lat ?? double.nan);
      ws.getRangeByIndex(r, 3).setNumber(lng ?? double.nan);
      ws.getRangeByIndex(r, 4).setText(photo ?? '');
      ws.getRangeByIndex(r, 5).setText(updated);

      r++;
    }

    // Ajustes básicos
    for (var c = 1; c <= headers.length; c++) {
      ws.autoFitColumn(c);
    }

    final bytes = book.saveAsStream();
    book.dispose();

    final dir = await getApplicationDocumentsDirectory();
    final outDir = Directory(p.join(dir.path, 'exports'))
      ..createSync(recursive: true);
    // Nombre amigable y único
    final safeName = sheet.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File(p.join(outDir.path, '${safeName}_${sheet.id}.xlsx'));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  String _formatTs(dynamic ts) {
    if (ts is DateTime) {
      return _fmt(ts);
    }
    if (ts is int) {
      return _fmt(DateTime.fromMillisecondsSinceEpoch(ts));
    }
    return '';
  }

  String _fmt(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }
}
