// lib/export/flexible_grid_exporter.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xls;

class FlexibleGridExporter {
  /// titles: títulos de columnas libres (longitud N)
  /// data:   lista de filas; cada fila es un Map<String,String> de los campos libres
  /// photos: lista de listas con paths por fila
  /// locs:   lista de pares [lat,lng] por fila (pueden ser nulls)
  static Future<File> export({
    required List<String> titles,
    required List<Map<String, String>> data,
    required List<List<String>> photos,
    required List<(double?, double?)> locs,
    String sheetName = 'Planilla',
    String filePrefix = 'export',
  }) async {
    final book = xls.Workbook();
    final ws = book.worksheets[0];
    ws.name = sheetName;

    // Encabezados
    final headers = [
      ...titles.map((t) => t.isEmpty ? '(Columna)' : t),
      'Fotos',
      'Lat',
      'Lng',
    ];
    for (var c = 0; c < headers.length; c++) {
      final cell = ws.getRangeByIndex(1, c + 1);
      cell.setText(headers[c]);
      cell.cellStyle.bold = true;
    }

    // Filas
    var r = 2;
    for (var i = 0; i < data.length; i++, r++) {
      final row = data[i];
      // columnas libres
      for (var c = 0; c < titles.length; c++) {
        ws.getRangeByIndex(r, c + 1).setText(row['f${c + 1}'] ?? '');
      }
      // fotos (paths separados por salto de línea)
      ws.getRangeByIndex(r, titles.length + 1)
          .setText((photos[i].isEmpty) ? '' : photos[i].join('\n'));

      // loc
      final (lat, lng) = locs[i];
      if (lat != null) ws.getRangeByIndex(r, titles.length + 2).setNumber(lat);
      if (lng != null) ws.getRangeByIndex(r, titles.length + 3).setNumber(lng);
    }

    // autosize
    for (var c = 1; c <= headers.length; c++) {
      ws.autoFitColumn(c);
    }

    final bytes = book.saveAsStream();
    book.dispose();

    final dir = await getApplicationDocumentsDirectory();
    final outDir = Directory(p.join(dir.path, 'exports'))..createSync(recursive: true);
    final file = File(p.join(
      outDir.path,
      '${filePrefix}_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    ));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
