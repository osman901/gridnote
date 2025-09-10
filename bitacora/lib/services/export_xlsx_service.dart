// lib/services/export_xlsx_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xls;

class ExportXlsxService {
  const ExportXlsxService();

  /// Exporta XLSX real con autoFit y miniatura por fila.
  /// [imageColumnIndex] es 1-based y apunta a la columna “Fotos”.
  Future<File> exportToXlsx({
    required List<String> headers,
    required List<List<String>> rows,
    Map<int, List<String>>? imagesByRow,
    int? imageColumnIndex, // 1-based
    String sheetName = 'Hoja',
    bool autoOpen = false,
  }) async {
    final book = xls.Workbook();
    final sheet = book.worksheets[0];
    sheet.name = sheetName;

    var r = 1;

    // Encabezados
    if (headers.isNotEmpty) {
      for (var c = 0; c < headers.length; c++) {
        sheet.getRangeByIndex(r, c + 1).setText(headers[c]);
      }
      final headerRange = sheet.getRangeByIndex(1, 1, 1, headers.length);
      headerRange.cellStyle.bold = true;
      headerRange.cellStyle.borders.all.lineStyle = xls.LineStyle.thin;
      r++;
    }

    // Filas
    var maxCols = headers.isNotEmpty ? headers.length : 1;
    for (final row in rows) {
      for (var c = 0; c < row.length; c++) {
        final cell = sheet.getRangeByIndex(r, c + 1);
        cell.setText(row[c]);
        cell.cellStyle.borders.all.lineStyle = xls.LineStyle.hair;
      }
      if (row.length > maxCols) maxCols = row.length;
      r++;
    }

    // AutoFit columnas
    for (var c = 1; c <= maxCols; c++) {
      sheet.autoFitColumn(c);
    }

    // Miniaturas por fila (usa la PRIMERA imagen de cada fila; sin offsets)
    if (imagesByRow != null && imagesByRow.isNotEmpty && imageColumnIndex != null) {
      const int thumbH = 42; // px aprox
      const int thumbW = 100;

      final hasHeader = headers.isNotEmpty;
      imagesByRow.forEach((rowIndex0, paths) {
        if (paths.isEmpty) return;
        final excelRow = (hasHeader ? 2 : 1) + rowIndex0;

        try {
          final bytes = File(paths.first).readAsBytesSync();
          final pic = sheet.pictures.addStream(
            excelRow,
            imageColumnIndex,
            Uint8List.fromList(bytes),
          );
          // Propiedades de tamaño son enteras
          pic.height = thumbH;
          pic.width = thumbW;

          // Asegura altura de fila suficiente (rowHeight es double)
          final current = sheet.getRangeByIndex(excelRow, 1).rowHeight;
          final needed = (thumbH + 6).toDouble();
          if (needed > current) {
            sheet.getRangeByIndex(excelRow, 1).rowHeight = needed;
          }
        } catch (_) {
          // Ignorar archivos ilegibles
        }
      });
    }

    final bytes = book.saveAsStream();
    book.dispose();

    final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final dir = await _exportDir();
    final file = File('${dir.path}/Bitacora_$ts.xlsx');
    await file.writeAsBytes(bytes, flush: true);

    if (autoOpen) {
      await OpenFilex.open(file.path);
    }
    return file;
  }

  Future<Directory> _exportDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/exports');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}

