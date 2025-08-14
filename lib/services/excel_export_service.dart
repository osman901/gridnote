// lib/services/excel_export_service.dart
import 'dart:typed_data';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

import '../models/measurement.dart';
import '../models/sheet_meta.dart';

class ExcelExportService {
  Future<Uint8List> buildExcelBytes({
    required List<Measurement> rows,
    required SheetMeta meta,
  }) async {
    final wb = xlsio.Workbook();
    final ws = wb.worksheets[0];

    // Nombre de hoja seguro (máx. 31)
    var sheetName = meta.name.trim().isEmpty ? 'Planilla' : meta.name.trim();
    if (sheetName.length > 31) sheetName = sheetName.substring(0, 31);
    ws.name = sheetName;

    // Encabezados
    final headers = ['Progresiva', '1 m Ω', '3 m Ω', 'Obs', 'Fecha'];
    for (var i = 0; i < headers.length; i++) {
      ws.getRangeByIndex(1, i + 1).setText(headers[i]);
    }

    // Estilo encabezado
    final header = wb.styles.add('header');
    header.bold = true;
    header.hAlign = xlsio.HAlignType.left;
    header.backColor = '#E6F3F8';
    header.borders.all.lineStyle = xlsio.LineStyle.thin;
    header.borders.all.color = '#D9DEE5';
    ws.getRangeByIndex(1, 1, 1, headers.length).cellStyle = header;

    // Datos
    for (var r = 0; r < rows.length; r++) {
      final m = rows[r];
      final i = r + 2; // fila excel (2 = debajo del header)
      ws.getRangeByIndex(i, 1).setText(m.progresiva);
      ws.getRangeByIndex(i, 2).setNumber(m.ohm1m);
      ws.getRangeByIndex(i, 3).setNumber(m.ohm3m);
      ws.getRangeByIndex(i, 4).setText(m.observations);
      final d = ws.getRangeByIndex(i, 5);
      d.setDateTime(m.date);
      d.numberFormat = 'dd/mm/yyyy';
    }

    // Bordes finos en toda el área con datos
    final lastRow = rows.length + 1; // incluye header
    ws
        .getRangeByIndex(1, 1, lastRow, headers.length)
        .cellStyle
        .borders
        .all
      ..lineStyle = xlsio.LineStyle.hair
      ..color = '#E6E9EF';

    // Anchos de columna
    final columnWidths = <double>[18, 12, 12, 28, 16];
    for (var c = 0; c < columnWidths.length; c++) {
      ws.getRangeByIndex(1, c + 1).columnWidth = columnWidths[c];
    }

    // ===== Estadísticas columnas B y C (ohm1m / ohm3m) =====
    if (rows.isNotEmpty) {
      final start = 2;               // primera fila de datos
      final end = rows.length + 1;   // última fila de datos
      var r0 = end + 2;              // fila inicial de stats (espacio en blanco)

      ws.getRangeByIndex(r0 - 1, 1).setText('Estadísticas');

      void statRow(String label, String func, {bool isMode = false}) {
        ws.getRangeByIndex(r0, 1).setText(label);

        final bFormula =
        isMode ? 'IFERROR(MODE.SNGL(B$start:B$end),"—")' : '$func(B$start:B$end)';
        final cFormula =
        isMode ? 'IFERROR(MODE.SNGL(C$start:C$end),"—")' : '$func(C$start:C$end)';

        ws.getRangeByIndex(r0, 2).setFormula(bFormula);
        ws.getRangeByIndex(r0, 3).setFormula(cFormula);

        // Formato numérico solo para Máx/Mín/Promedio (no para Moda)
        if (!isMode) {
          ws.getRangeByIndex(r0, 2, r0, 3).numberFormat = '0.00';
        }

        r0++;
      }

      statRow('Máximo',   'MAX');
      statRow('Mínimo',   'MIN');
      statRow('Promedio', 'AVERAGE');
      statRow('Moda',     '', isMode: true);
    }

    // Guardar
    final bytes = wb.saveAsStream();
    wb.dispose();
    return Uint8List.fromList(bytes);
  }
}
