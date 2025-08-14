import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import '../models/measurement.dart';

class MeasurementExcelService {
  /// Exporta una lista de Measurement a XLSX y abre el share sheet.
  /// [headers] permite customizar los títulos visibles.
  static Future<void> shareExcel({
    required BuildContext context,
    required List<Measurement> data,
    Map<String, String>? headers,
    String suggestedFileName = '',
  }) async {
    final bytes = _buildXlsxBytes(
      data: data,
      headers: headers ??
          const {
            'progresiva': 'Progresiva',
            'ohm1m': 'Ω (1 m)',
            'ohm3m': 'Ω (3 m)',
            'observations': 'Observaciones',
            'date': 'Fecha',
          },
    );

    final tmpDir = await getTemporaryDirectory();
    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '');
    final fileName = '${suggestedFileName.isEmpty
            ? 'planilla_$ts'
            : '${suggestedFileName}_$ts'}.xlsx';
    final file = File(p.join(tmpDir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);

    // ignore: deprecated_member_use
    await Share.shareXFiles(
      [
        XFile(file.path,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      ],
      subject: 'Gridnote – Reporte XLSX',
      text: 'Adjunto Excel generado desde Gridnote.',
    );
  }

  /// Construye bytes XLSX en memoria a partir de Measurement[]
  static List<int> _buildXlsxBytes({
    required List<Measurement> data,
    required Map<String, String> headers,
  }) {
    final wb = xlsio.Workbook();
    final sheet = wb.worksheets[0];

    // Encabezados
    final hdrs = [
      headers['progresiva'] ?? 'Progresiva',
      headers['ohm1m'] ?? 'Ω (1 m)',
      headers['ohm3m'] ?? 'Ω (3 m)',
      headers['observations'] ?? 'Observaciones',
      headers['date'] ?? 'Fecha',
    ];
    for (var c = 0; c < hdrs.length; c++) {
      final cell = sheet.getRangeByIndex(1, c + 1);
      cell.setText(hdrs[c]);
      cell.cellStyle.bold = true;
    }

    // Filas
    for (var i = 0; i < data.length; i++) {
      final m = data[i];

      // Col 1: Progresiva (texto)
      sheet.getRangeByIndex(i + 2, 1).setText(m.progresiva);

      // Col 2: Ω 1m (número)
      sheet.getRangeByIndex(i + 2, 2).setNumber(m.ohm1m);

      // Col 3: Ω 3m (número)
      sheet.getRangeByIndex(i + 2, 3).setNumber(m.ohm3m);

      // Col 4: Observaciones (texto)
      sheet.getRangeByIndex(i + 2, 4).setText(m.observations);

      // Col 5: Fecha (texto dd/MM/yyyy)
      final d = m.date;
      final fecha =
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      sheet.getRangeByIndex(i + 2, 5).setText(fecha);
    }

    // Ajuste de ancho
    for (var c = 1; c <= 5; c++) {
      sheet.autoFitColumn(c);
    }

    final bytes = wb.saveAsStream();
    wb.dispose();
    return bytes;
  }
}
