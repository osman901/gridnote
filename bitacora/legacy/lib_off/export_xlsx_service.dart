import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xls;

/// Exporta XLSX real offline. Inserta imágenes por fila en columnas nuevas.
/// Sin dependencias de DAO. Úsalo con headers/rows ya armados.
class ExportXlsxService {
  ExportXlsxService();

  Future<File> exportToXlsx({
    required List<String> headers,
    required List<List<String>> rows,
    Map<int, List<String>>? imagesByRow,
    String sheetName = 'Hoja',
    bool autoOpen = false,
  }) async {
    final book = xls.Workbook();
    final sheet = book.worksheets[0];
    sheet.name = sheetName;

    var r = 1;

    // Headers
    if (headers.isNotEmpty) {
      for (int c = 0; c < headers.length; c++) {
        sheet.getRangeByIndex(r, c + 1).setText(headers[c]);
      }
      final headerRange = sheet.getRangeByIndex(1, 1, 1, headers.length);
      headerRange.cellStyle.bold = true;
      headerRange.cellStyle.borders.all.lineStyle = xls.LineStyle.thin;
      r++;
    }

    // Filas
    int maxCols = headers.isNotEmpty ? headers.length : 1;
    for (final row in rows) {
      for (int c = 0; c < row.length; c++) {
        final cell = sheet.getRangeByIndex(r, c + 1);
        cell.setText(row[c]);
        cell.cellStyle.borders.all.lineStyle = xls.LineStyle.hair;
      }
      if (row.length > maxCols) maxCols = row.length;
      r++;
    }

    // Imágenes: Foto1..N desde la primera columna libre
    if (imagesByRow != null && imagesByRow.isNotEmpty) {
      final maxPhotos =
      imagesByRow.values.fold<int>(0, (acc, l) => l.length > acc ? l.length : acc);
      if (maxPhotos > 0) {
        final startColForPhotos = maxCols + 1;

        // Encabezados Foto1..N
        if (headers.isNotEmpty) {
          for (int j = 0; j < maxPhotos; j++) {
            sheet.getRangeByIndex(1, startColForPhotos + j).setText('Foto ${j + 1}');
          }
        }

        const int imgHeight = 42;
        const int imgWidth = 100;

        imagesByRow.forEach((rowIndex0, paths) {
          final excelRow = (headers.isNotEmpty ? 2 : 1) + rowIndex0;
          for (int j = 0; j < paths.length; j++) {
            final col = startColForPhotos + j;
            try {
              final bytes = File(paths[j]).readAsBytesSync();
              final pic = sheet.pictures.addStream(
                excelRow,
                col,
                Uint8List.fromList(bytes),
              );
              pic.height = imgHeight;
              pic.width = imgWidth;

              final current = sheet.getRangeByIndex(excelRow, 1).rowHeight;
              final needed = (imgHeight + 6).toDouble();
              if (needed > current) {
                sheet.getRangeByIndex(excelRow, 1).rowHeight = needed;
              }
            } catch (_) {
              // Ignorar archivos ilegibles
            }
          }
        });

        maxCols = startColForPhotos + maxPhotos - 1;
      }
    }

    // AutoFit
    for (int c = 1; c <= maxCols; c++) {
      sheet.autoFitColumn(c);
    }

    // Guardar
    final bytes = book.saveAsStream();
    book.dispose();

    final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final dir = await _exportDir();
    final file = File(p.join(dir.path, 'Bitacora_$ts.xlsx'));
    await file.writeAsBytes(bytes, flush: true);

    if (autoOpen) {
      await OpenFilex.open(file.path);
    }
    return file;
  }

  Future<Directory> _exportDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'exports'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
