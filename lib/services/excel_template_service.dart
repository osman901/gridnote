// lib/services/excel_template_service.dart
import 'dart:io';
import 'package:excel/excel.dart' as ex;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// Servicio simple de “plantilla” en memoria + exportación a XLSX usando package:excel ^4.x
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
    final book = ex.Excel.createExcel();

    // Renombramos la hoja por defecto a la primera del map (si existe)
    final def = book.getDefaultSheet();
    final names = _sheets.keys.toList(growable: false);
    if (names.isEmpty) {
      names.add('Hoja1');
      _sheets['Hoja1'] = <List<String>>[];
    }
    if (def != null && def != names.first) {
      book.rename(def, names.first);
    }

    for (final name in names) {
      final sh = book[name]; // crea si no existe
      for (final row in _sheets[name]!) {
        sh.appendRow(
          row
              .map<ex.CellValue>((s) {
            final d = double.tryParse(s);
            return (d == null) ? ex.TextCellValue(s) : ex.DoubleCellValue(d);
          })
              .toList(growable: false),
        );
      }
    }

    final bytes = book.save();
    if (bytes == null) {
      throw Exception('No se pudo serializar el Excel.');
    }
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
