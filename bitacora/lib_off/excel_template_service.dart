import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xls;

/// Servicio simple de “plantilla” en memoria + exportación a XLSX usando Syncfusion XlsIO.
/// API: load / matrix / setValue / saveToFile.
class ExcelTemplateService {
  final Map<String, List<List<String>>> _sheets = <String, List<List<String>>>{};

  /// Crea en memoria las hojas indicadas si no existen.
  Future<void> load({required List<String> sheetNames}) async {
    for (final name in sheetNames) {
      _sheets.putIfAbsent(
        name,
            () => List.generate(12, (_) => List.filled(4, ''), growable: true),
      );
    }
  }

  /// Devuelve la matriz (lista de filas; cada fila es lista de celdas String).
  List<List<String>> matrix(String sheetName) =>
      _sheets[sheetName] ?? const <List<String>>[];

  /// Escribe asegurando tamaño.
  void setValue(String sheetName, int row, int col, String value) {
    final sheet = _sheets.putIfAbsent(sheetName, () => <List<String>>[]);
    while (sheet.length <= row) {
      sheet.add(<String>[]);
    }
    final r = sheet[row];
    while (r.length <= col) {
      r.add('');
    }
    r[col] = value;
  }

  /// Persiste a archivo XLSX. Si [openAfterSave] es true, intenta abrirlo.
  Future<String> saveToFile({
    String fileName = 'gridnote.xlsx',
    bool openAfterSave = false,
  }) async {
    final book = xls.Workbook();

    // Si no hay hojas en memoria, creamos una por defecto.
    if (_sheets.isEmpty) {
      _sheets['Hoja1'] = <List<String>>[];
    }

    // La primera hoja del workbook es la [0]; la renombramos al primer nombre.
    final firstName = _sheets.keys.first;
    final firstSheet = book.worksheets[0];
    firstSheet.name = firstName;

    // Aseguramos que existan el resto de hojas y volcamos datos.
    var sheetIndex = 0;
    for (final entry in _sheets.entries) {
      xls.Worksheet sheet;
      if (sheetIndex == 0) {
        sheet = firstSheet;
      } else {
        sheet = book.worksheets.addWithName(entry.key);
      }
      sheetIndex++;

      final rows = entry.value;
      // Escribir fila por fila
      for (var r = 0; r < rows.length; r++) {
        final row = rows[r];
        for (var c = 0; c < row.length; c++) {
          final cell = sheet.getRangeByIndex(r + 1, c + 1);
          // Intento numérico simple
          final asNum = double.tryParse(row[c]);
          if (asNum != null) {
            cell.setNumber(asNum);
          } else {
            cell.setText(row[c]);
          }
        }
      }

      // AutoFit de columnas usadas
      final maxCols = rows.isEmpty ? 0 : rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
      for (int c = 1; c <= maxCols; c++) {
        sheet.autoFitColumn(c);
      }
    }

    // Guardar en disco
    final List<int> bytes = book.saveAsStream(); // <- List<int>, no Uint8List
    book.dispose();

    final dir = await getApplicationDocumentsDirectory();
    final out = File('${dir.path}/${_safeXlsx(fileName)}');
    await out.writeAsBytes(bytes, flush: true);

    if (openAfterSave) {
      // ignore: discarded_futures
      OpenFilex.open(out.path);
    }
    return out.path;
  }

  static String _safeXlsx(String name) {
    var n = name.trim().isEmpty ? 'gridnote' : name.trim();
    n = n.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (!n.toLowerCase().endsWith('.xlsx')) n = '$n.xlsx';
    return n;
  }
}

