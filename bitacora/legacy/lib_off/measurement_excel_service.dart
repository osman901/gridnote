import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/measurement.dart';
import 'xlsx_export_service.dart';

class MeasurementExcelService {
  /// Genera el XLSX usando el XlsxExportService.
  static Future<File> buildExcelFile({
    required List<Measurement> data,
    String? sheetId,
    List<String>? headers,
    String title = 'Planilla',
    double? defaultLat,
    double? defaultLng,
  }) {
    final svc = XlsxExportService();
    return svc.buildFile(
      sheetId: sheetId ?? 'adhoc', // si no te pasan sheetId no se embeben fotos
      title: title,
      data: data,
      headers: headers,
      defaultLat: defaultLat,
      defaultLng: defaultLng,
    );
  }

  /// Exporta a XLSX y abre el share sheet.
  static Future<void> shareExcel({
    required BuildContext context,
    required List<Measurement> data,
    Map<String, String>? headers,
    String suggestedFileName = '',
    String? sheetId,
    double? defaultLat,
    double? defaultLng,
  }) async {
    final h = headers ?? const {};
    // Nueva columna ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã¢â‚¬Å“UbicaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³nÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â (reemplaza Lat/Lng)
    final cols = <String>[
      h['date'] ?? 'Fecha',
      h['progresiva'] ?? 'Progresiva',
      h['ohm1m'] ?? '1m (ÃƒÆ’Ã…Â½Ãƒâ€šÃ‚Â©)',
      h['ohm3m'] ?? '3m (ÃƒÆ’Ã…Â½Ãƒâ€šÃ‚Â©)',
      h['observations'] ?? 'Obs',
      'UbicaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n',
    ];

    final base = suggestedFileName.isEmpty ? 'Planilla' : suggestedFileName;
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '').replaceAll('.', '');
    final title = '$base $stamp';

    final file = await buildExcelFile(
      data: data,
      sheetId: sheetId, // si lo pasÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡s, embebe fotos por fila
      headers: cols,
      title: title,
      defaultLat: defaultLat,
      defaultLng: defaultLng,
    );

    await Share.shareXFiles(
      [
        XFile(
          file.path,
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      ],
      subject: 'Gridnote ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œ Reporte XLSX',
      text: 'Adjunto Excel generado desde Gridnote.',
    );
  }
}
