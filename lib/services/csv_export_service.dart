// lib/services/csv_export_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../models/measurement.dart';

class CsvExportService {
  static const List<String> _fallbackHeaders = [
    'Fecha', 'Progresiva', '1m (Ω)', '3m (Ω)', 'Observaciones', 'Lat', 'Lng'
  ];

  /// API principal
  static Future<File> export({
    required List<Measurement> rows,
    required String fileName,
    List<String>? headers,
  }) async {
    final cols = (headers != null && headers.isNotEmpty)
        ? headers
        : _fallbackHeaders;

    final buffer = StringBuffer();
    buffer.writeln(_listToCsvRow(cols));

    for (final m in rows) {
      buffer.writeln(_listToCsvRow([
        m.dateString,
        m.progresiva,
        m.ohm1m.toString(),
        m.ohm3m.toString(),
        m.observations,
        m.latitude?.toString() ?? '',
        m.longitude?.toString() ?? '',
      ]));
    }

    final dir = await getTemporaryDirectory(); // arch. temporal
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(buffer.toString(), flush: true, encoding: utf8);
    return file;
  }

  /// Alias para compatibilidad con SheetScreen:
  /// permite llamar: CsvExportService.exportMeasurements(rows, fileName: name)
  static Future<File> exportMeasurements(
      List<Measurement> rows, {
        required String fileName,
        List<String>? headers,
      }) {
    return export(rows: rows, fileName: fileName, headers: headers);
  }

  // --- helpers CSV (RFC 4180) ---
  static String _listToCsvRow(List<String> fields) =>
      fields.map(_escapeCsvField).join(',');

  static String _escapeCsvField(String? field) {
    final f = field ?? '';
    if (f.contains(',') || f.contains('"') || f.contains('\n') || f.contains('\r')) {
      final escaped = f.replaceAll('"', '""');
      return '"$escaped"';
    }
    return f;
  }
}
