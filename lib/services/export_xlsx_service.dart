// lib/services/export_xlsx_service.dart
import 'dart:io';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as sx;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../models/free_sheet.dart';

class ExportXlsxService {
  ExportXlsxService._();
  static final ExportXlsxService instance = ExportXlsxService._();

  Future<String> export(FreeSheetData d, {String? fileName}) async {
    final wb = sx.Workbook();
    final sh = wb.worksheets[0];

    // Nombre de hoja (máx. 31 en Excel; usamos 30 para margen)
    final rawSheetName = d.name.isEmpty ? 'Hoja' : d.name;
    final safeSheetName =
    rawSheetName.substring(0, rawSheetName.length > 30 ? 30 : rawSheetName.length);
    sh.name = safeSheetName;

    // Headers
    final headerStyle = wb.styles.add('hdr')
      ..bold = true
      ..hAlign = sx.HAlignType.left;
    for (var c = 0; c < d.headers.length; c++) {
      sh.getRangeByIndex(1, c + 1).setText(d.headers[c]);
      sh.getRangeByIndex(1, c + 1).cellStyle = headerStyle;
      sh.setColumnWidthInPixels(c + 1, 180);
    }

    bool isImg(String v) {
      final ext = p.extension(v).toLowerCase();
      return ext == '.png' || ext == '.jpg' || ext == '.jpeg' || ext == '.webp';
    }

    // Filas
    for (var r = 0; r < d.rows.length; r++) {
      final row = d.rows[r];
      for (var c = 0; c < d.headers.length; c++) {
        if (c >= row.length) continue;

        final v = (row[c] ?? '').toString();
        final cell = sh.getRangeByIndex(r + 2, c + 1);

        if (v.startsWith('geo:')) {
          final q = v.replaceFirst('geo:', '');
          final url = 'https://www.google.com/maps/search/?api=1&query=$q';
          cell.setText(q);
          sh.hyperlinks.add(cell, sx.HyperlinkType.url, url);
        } else if (v.startsWith('file://') || v.startsWith('/')) {
          final path = v.startsWith('file://') ? Uri.parse(v).toFilePath() : v;
          if (await File(path).exists() && isImg(path)) {
            final bytes = File(path).readAsBytesSync();
            final pic = sh.pictures.addStream(r + 2, c + 1, bytes);
            pic.lastRow = r + 2;
            pic.lastColumn = c + 1;
            cell.setText('');
          } else {
            cell.setText(v);
          }
        } else {
          cell.setText(v);
        }
      }
    }

    // Auto-fit de filas
    for (var r = 1; r <= d.rows.length + 1; r++) {
      sh.autoFitRow(r);
    }

    final bytes = wb.saveAsStream();
    wb.dispose();

    final baseName = fileName ?? (d.name.isNotEmpty ? d.name : 'gridnote');
    final fname = baseName.replaceAll(RegExp(r'[^\w\s\-]'), '').trim();
    final dir = await getTemporaryDirectory();
    final out = p.join(dir.path, '$fname.xlsx');
    await File(out).writeAsBytes(bytes, flush: true);
    return out;
  }
}
