// lib/services/xlsx_export_service.dart
import 'dart:io';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xls;
import 'package:path_provider/path_provider.dart';

import '../models/measurement.dart';
import '../services/photo_store.dart';

class XlsxExportService {
  static const List<String> _fallbackHeaders = <String>[
    'Fecha', 'Progresiva', '1m (Ω)', '3m (Ω)', 'Observaciones', 'Lat', 'Lng'
  ];

  /// Genera un XLSX con dos hojas:
  /// - "Datos": tabla con las mediciones.
  /// - "Fotos": mini-galería embebida por fila.
  Future<File> buildFile({
    required String sheetId,
    required String title,
    required List<Measurement> data,
    double? defaultLat,
    double? defaultLng,
    List<String>? headers,
  }) async {
    final normalized = data
        .map((m) => (m.latitude == null && defaultLat != null) ||
        (m.longitude == null && defaultLng != null)
        ? m.copyWith(
      latitude: m.latitude ?? defaultLat,
      longitude: m.longitude ?? defaultLng,
    )
        : m)
        .toList(growable: false);

    final book = xls.Workbook();
    final ws = book.worksheets[0];
    ws.name = 'Datos';

    // Encabezados
    final cols = (headers != null && headers.isNotEmpty) ? headers : _fallbackHeaders;
    for (var c = 0; c < cols.length; c++) {
      ws.getRangeByIndex(1, c + 1).setText(cols[c]);
      ws.getRangeByIndex(1, c + 1).cellStyle.bold = true;
    }

    String _fmtDate(DateTime? dt) {
      if (dt == null) return '';
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    }

    // Filas
    for (var i = 0; i < normalized.length; i++) {
      final r = i + 2;
      final m = normalized[i];
      ws.getRangeByIndex(r, 1).setText(_fmtDate(m.date));
      ws.getRangeByIndex(r, 2).setText(m.progresiva);
      ws.getRangeByIndex(r, 3).setNumber((m.ohm1m ?? 0).toDouble());
      ws.getRangeByIndex(r, 4).setNumber((m.ohm3m ?? 0).toDouble());
      ws.getRangeByIndex(r, 5).setText(m.observations ?? '');
      if (m.latitude != null) ws.getRangeByIndex(r, 6).setNumber(m.latitude!);
      if (m.longitude != null) ws.getRangeByIndex(r, 7).setNumber(m.longitude!);
    }

    // Hoja de fotos
    final fotos = book.worksheets.addWithName('Fotos');
    fotos.getRangeByIndex(1, 1).setText('Progresiva');
    fotos.getRangeByIndex(1, 2).setText('Foto #');
    fotos.getRangeByIndex(1, 3).setText('Imagen');
    fotos.getRangeByIndex(1, 1).cellStyle.bold = true;
    fotos.getRangeByIndex(1, 2).cellStyle.bold = true;
    fotos.getRangeByIndex(1, 3).cellStyle.bold = true;

    var rowPix = 2;
    for (final m in normalized) {
      final rid = m.id ?? '';
      final files = await PhotoStore.list(sheetId, rid);
      if (files.isEmpty) continue;

      var idx = 1;
      for (final f in files) {
        final bytes = await f.readAsBytes();
        fotos.getRangeByIndex(rowPix, 1).setText(m.progresiva);
        fotos.getRangeByIndex(rowPix, 2).setNumber(idx.toDouble());

        final pic = fotos.pictures.addStream(rowPix, 3, bytes);
        pic.height = 180;
        pic.width = 240;

        rowPix += 8; // separador vertical
        idx++;
      }
    }

    final bytes = book.saveAsStream();
    book.dispose();

    // Guardamos en Support (seguro y privado)
    final dir = await getApplicationSupportDirectory();
    final safeName = _safe('${title}_xlsx');
    final out = File('${dir.path}/$safeName');
    await out.writeAsBytes(bytes, flush: true);
    return out;
  }

  static String _safe(String name) {
    var n = name.trim().isEmpty ? 'gridnote' : name.trim();
    n = n.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').replaceAll(RegExp(r'\s+'), '_');
    if (!n.toLowerCase().endsWith('.xlsx')) n = '$n.xlsx';
    return n;
  }
}
