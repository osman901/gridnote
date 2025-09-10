import 'dart:io';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xls;
import 'package:path_provider/path_provider.dart';

import '../models/measurement.dart';
import '../services/photo_store.dart';

class XlsxExportService {
  static const List<String> _fallbackHeaders = <String>[
    'Fecha', 'Progresiva', '1m (Ω)', '3m (Ω)', 'Observaciones', 'Ubicación'
  ];

  /// Genera un XLSX con dos hojas:
  /// - "Datos": tabla con las mediciones. La columna "Ubicación" contiene
  ///   un link clickeable a Google Maps por fila.
  /// - "Fotos": mini-galería embebida por fila.
  Future<File> buildFile({
    required String sheetId,
    required String title,
    required List<Measurement> data,
    double? defaultLat,
    double? defaultLng,
    List<String>? headers,
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

    final cols = (headers != null && headers.isNotEmpty) ? headers : _fallbackHeaders;
    for (var c = 0; c < cols.length; c++) {
      final cell = ws.getRangeByIndex(1, c + 1);
      cell.setText(cols[c]);
      cell.cellStyle.bold = true;
    }

    String fmtDate(DateTime? dt) {
      if (dt == null) return '';
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    }

    for (var i = 0; i < normalized.length; i++) {
      final r = i + 2;
      final m = normalized[i];

      ws.getRangeByIndex(r, 1).setText(fmtDate(m.date));
      ws.getRangeByIndex(r, 2).setText(m.progresiva);
      ws.getRangeByIndex(r, 3).setNumber(m.ohm1m.toDouble());
      ws.getRangeByIndex(r, 4).setNumber(m.ohm3m.toDouble());
      ws.getRangeByIndex(r, 5).setText(m.observations);

      // Columna 6: “Ubicación” con hyperlink si hay coords
      final lat = m.latitude;
      final lng = m.longitude;
      final locCell = ws.getRangeByIndex(r, 6);
      if (lat != null && lng != null) {
        final url = _mapsUrl(lat, lng);
        final link = ws.hyperlinks.add(locCell, xls.HyperlinkType.url, url);
        link.textToDisplay = 'Enlace ubicación';
      } else {
        locCell.setText('');
      }
    }

    // ================= Hoja Fotos =================
    final fotos = book.worksheets.addWithName('Fotos');
    fotos.getRangeByIndex(1, 1).setText('Progresiva');
    fotos.getRangeByIndex(1, 2).setText('Foto #');
    fotos.getRangeByIndex(1, 3).setText('Imagen');
    for (var c = 1; c <= 3; c++) {
      fotos.getRangeByIndex(1, c).cellStyle.bold = true;
    }

    var rowPix = 2;
    for (final m in normalized) {
      final int rid = m.id ?? 0;
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

        rowPix += 8; // separación visual
        idx++;
      }
    }

    final bytes = book.saveAsStream();
    book.dispose();

    // Guardamos en ApplicationSupportDirectory (privado)
    final dir = await getApplicationSupportDirectory();
    final out = File('${dir.path}/${_safe('${title}_xlsx')}');
    await out.writeAsBytes(bytes, flush: true);
    return out;
  }

  static String _mapsUrl(double lat, double lng) =>
      'https://www.google.com/maps/search/?api=1&query=${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';

  static String _safe(String name) {
    var n = name.trim().isEmpty ? 'gridnote' : name.trim();
    n = n.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').replaceAll(RegExp(r'\s+'), '_');
    if (!n.toLowerCase().endsWith('.xlsx')) n = '$n.xlsx';
    return n;
  }
}