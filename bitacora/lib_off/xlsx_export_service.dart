// lib/services/xlsx_export_service.dart
import 'dart:io';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xls;
import 'package:path_provider/path_provider.dart';

import '../models/measurement.dart';

class XlsxExportService {
  static const List<String> _fallbackHeaders = <String>[
    'Fecha',
    'Progresiva',
    '1 m (ÃƒÅ½Ã‚Â©)',
    '3 m (ÃƒÅ½Ã‚Â©)',
    'Observaciones',
    'UbicaciÃƒÆ’Ã‚Â³n',
  ];

  /// Genera un XLSX con:
  /// - "Datos": tabla con las mediciones y link a Maps si hay lat/lng.
  /// - "Fotos": (opcional) mini-galerÃƒÆ’Ã‚Â­a si provees [getPhotos].
  Future<File> buildFile({
    required String sheetId, // compat de firma
    required String title,
    required List<Measurement> data,
    double? defaultLat,
    double? defaultLng,
    List<String>? headers,
    List<String> Function(Measurement m)? getPhotos,
  }) async {
    // Normaliza coordenadas con defaults si faltan.
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

    // ================= Hoja Datos =================
    final ws = book.worksheets[0];
    ws.name = 'Datos';

    final cols = (headers != null && headers.isNotEmpty)
        ? headers
        : _fallbackHeaders;

    // Encabezados
    for (var c = 0; c < cols.length; c++) {
      final cell = ws.getRangeByIndex(1, c + 1);
      cell.setText(cols[c]);
      cell.cellStyle.bold = true;
    }

    for (var i = 0; i < normalized.length; i++) {
      final r = i + 2;
      final m = normalized[i];

      ws.getRangeByIndex(r, 1).setText(_fmtDate(m.date));
      ws.getRangeByIndex(r, 2).setText(m.progresiva);

      _setNumOrEmpty(ws, r, 3, m.ohm1m);
      _setNumOrEmpty(ws, r, 4, m.ohm3m);

      ws.getRangeByIndex(r, 5).setText(m.observations);

      // Columna 6: ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œUbicaciÃƒÆ’Ã‚Â³nÃƒÂ¢Ã¢â€šÂ¬Ã‚Â con hyperlink si hay coords
      final lat = m.latitude;
      final lng = m.longitude;
      final locCell = ws.getRangeByIndex(r, 6);
      if (lat != null && lng != null) {
        final url =
            'https://www.google.com/maps/search/?api=1&query=${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
        final link = ws.hyperlinks.add(locCell, xls.HyperlinkType.url, url);
        link.textToDisplay = 'Enlace ubicaciÃƒÆ’Ã‚Â³n';
      } else {
        locCell.setText('');
      }
    }

    // Autoajuste simple de columnas
    for (var c = 1; c <= cols.length; c++) {
      ws.autoFitColumn(c);
    }

    // ================= Hoja Fotos (opcional) =================
    if (getPhotos != null) {
      final fotos = book.worksheets.addWithName('Fotos');
      fotos.getRangeByIndex(1, 1).setText('Progresiva');
      fotos.getRangeByIndex(1, 2).setText('Foto #');
      fotos.getRangeByIndex(1, 3).setText('Imagen');
      for (var c = 1; c <= 3; c++) {
        fotos.getRangeByIndex(1, c).cellStyle.bold = true;
      }

      var row = 2;
      for (final m in normalized) {
        final paths = getPhotos(m);
        if (paths.isEmpty) continue;

        var idx = 1;
        for (final path in paths) {
          try {
            final file = File(path);
            if (!await file.exists()) {
              idx++;
              continue;
            }
            final bytes = await file.readAsBytes();

            fotos.getRangeByIndex(row, 1).setText(m.progresiva);
            fotos.getRangeByIndex(row, 2).setNumber(idx.toDouble());

            // asegurar altura de fila para que no se corte la miniatura
            fotos.setRowHeightInPixels(row, 200);

            final pic = fotos.pictures.addStream(row, 3, bytes);
            pic.height = 180;
            pic.width = 240;

            row += 1; // una fila por imagen
            idx++;
          } catch (_) {
            idx++;
          }
        }
      }

      fotos.autoFitColumn(1);
      fotos.autoFitColumn(2);
    }

    final bytes = book.saveAsStream();
    book.dispose();

    final dir = await getApplicationSupportDirectory();
    final out = File('${dir.path}/${_safe('${title}_xlsx')}');
    await out.writeAsBytes(bytes, flush: true);
    return out;
  }

  // -------- helpers --------
  static void _setNumOrEmpty(xls.Worksheet ws, int r, int c, double? v) {
    if (v == null) {
      ws.getRangeByIndex(r, c).setText('');
    } else {
      ws.getRangeByIndex(r, c).setNumber(v);
    }
  }

  static String _fmtDate(DateTime? dt) {
    if (dt == null) return '';
    final d = dt.toLocal();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  static String _safe(String name) {
    var n = name.trim().isEmpty ? 'gridnote' : name.trim();
    n = n
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    if (!n.toLowerCase().endsWith('.xlsx')) n = '$n.xlsx';
    return n;
  }
}
