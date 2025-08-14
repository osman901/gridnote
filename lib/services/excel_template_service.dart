// lib/services/excel_template_service.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import '../models/measurement.dart';

class ExcelTemplateService {
  late Workbook _wb;

  /// Crea el workbook y agrega hojas por nombre.
  Future<void> load({List<String> sheetNames = const ['Hoja1']}) async {
    _wb = Workbook();
    _wb.worksheets[0].name = sheetNames.first;
    for (int i = 1; i < sheetNames.length; i++) {
      _wb.worksheets.addWithName(sheetNames[i]);
    }
  }

  List<String> get sheets => List.generate(
    _wb.worksheets.count,
        (i) => _wb.worksheets[i].name,
  );

  Worksheet _sheetByName(String name) {
    for (var i = 0; i < _wb.worksheets.count; i++) {
      final ws = _wb.worksheets[i];
      if (ws.name == name) return ws;
    }
    throw ArgumentError('Hoja no encontrada: $name');
  }

  /// Devuelve una matriz de textos de la hoja.
  List<List<String>> matrix(String sheetName) {
    final ws = _sheetByName(sheetName);
    final rows = ws.getLastRow();
    final cols = ws.getLastColumn();
    if (rows <= 0 || cols <= 0) return const [];

    return List.generate(rows, (r) {
      return List.generate(cols, (c) {
        final String text = ws.getRangeByIndex(r + 1, c + 1).displayText;
        return text; // displayText ya no es nullable
      });
    });
  }

  void setValue(String sheetName, int row, int col, String value) {
    final ws = _sheetByName(sheetName);
    ws.getRangeByIndex(row + 1, col + 1).setText(value);
  }

  /// Escribe todas las mediciones a una hoja (incluyendo lat/lon)
  void writeMeasurementsSheet(String sheetName, List<Measurement> measurements) {
    final ws = _sheetByName(sheetName);

    // Encabezados
    const headers = [
      'Progresiva',
      'Ohm 1m',
      'Ohm 3m',
      'Observaciones',
      'Latitud',
      'Longitud',
      'Fecha',
    ];
    for (int c = 0; c < headers.length; c++) {
      ws.getRangeByIndex(1, c + 1).setText(headers[c]);
    }
    ws.getRangeByName('A1:G1').cellStyle..bold = true;

    // Filas
    for (int r = 0; r < measurements.length; r++) {
      final m = measurements[r];
      final row = r + 2;

      ws.getRangeByIndex(row, 1).setText(m.progresiva);
      ws.getRangeByIndex(row, 2).setNumber(m.ohm1m.toDouble());
      ws.getRangeByIndex(row, 3).setNumber(m.ohm3m.toDouble());
      ws.getRangeByIndex(row, 4).setText(m.observations);
      ws.getRangeByIndex(row, 5).setNumber((m.latitude ?? 0.0).toDouble());
      ws.getRangeByIndex(row, 6).setNumber((m.longitude ?? 0.0).toDouble());

      // Guardar la fecha como fecha real de Excel
      ws.getRangeByIndex(row, 7).dateTime = m.date;
    }

    // Formatos
    final lastRow = measurements.isEmpty ? 2 : (measurements.length + 1);
    ws.getRangeByName('B2:C$lastRow').numberFormat = '0.00';
    ws.getRangeByName('E2:F$lastRow').numberFormat = '0.000000';
    ws.getRangeByName('G2:G$lastRow').numberFormat = 'dd/mm/yyyy';

    // Autofit columnas
    for (int c = 1; c <= 7; c++) {
      ws.autoFitColumn(c);
    }
  }

  Future<String> saveToFile({
    String fileName = 'gridnote.xlsx',
    bool openAfterSave = false,
  }) async {
    final bytes = _wb.saveAsStream();
    _wb.dispose();

    Directory? dir = await getDownloadsDirectory();
    dir ??= await getApplicationDocumentsDirectory();

    final path = p.join(dir.path, fileName);
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);

    if (openAfterSave) {
      await OpenFile.open(path);
    }
    return path;
  }
}