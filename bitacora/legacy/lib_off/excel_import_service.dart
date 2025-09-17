// lib/services/excel_import_service.dart
import 'dart:io';
import 'package:excel/excel.dart' as ex;
import '../models/measurement.dart';

class ExcelImportService {
  /// Lee un .xlsx y devuelve mediciones parseadas.
  static Future<List<Measurement>> readXlsx(File file) async {
    final bytes = await file.readAsBytes();
    final book = ex.Excel.decodeBytes(bytes);

    // 1) Tomar la primera hoja con filas reales
    ex.Sheet? sheet;
    for (final key in book.tables.keys) {
      final s = book.tables[key];
      if (s != null && s.maxRows > 0) {
        sheet = s;
        break;
      }
    }
    if (sheet == null) return <Measurement>[];

    // 2) Encabezados (primera fila no vacÃƒÆ’Ã‚Â­a)
    final rows = sheet.rows;
    if (rows.isEmpty) return <Measurement>[];

    final headerRowIdx =
    rows.indexWhere((r) => r.any((c) => _cellText(c).isNotEmpty));
    if (headerRowIdx < 0) return <Measurement>[];

    final headers =
    rows[headerRowIdx].map((c) => _normHeader(_cellText(c))).toList();
    final map = _buildHeaderMap(headers);

    // 3) Filas de datos
    final out = <Measurement>[];
    for (var i = headerRowIdx + 1; i < rows.length; i++) {
      final r = rows[i];

      String getS(String key) => _cellText(_cell(r, map[key]));
      double? getD(String key) => _toDouble(_cell(r, map[key]));
      DateTime? getT(String key) => _toDateTime(_cell(r, map[key]));

      final lat = getD('lat');
      final lng = getD('lng');
      final prog = getS('progresiva');
      final ohm1 = getD('ohm1');
      final ohm3 = getD('ohm3');
      final obs  = getS('obs');
      final dt   = getT('fecha') ?? DateTime.now();

      final hasCoords = lat != null && lng != null;
      final hasAnyValue = [
        prog.isNotEmpty, ohm1 != null, ohm3 != null, obs.isNotEmpty, hasCoords
      ].any((x) => x);
      if (!hasAnyValue) continue;

      out.add(
        Measurement(
          date: dt,
          progresiva: prog.isEmpty ? _fallbackProgresiva(i) : prog,
          ohm1m: ohm1,
          ohm3m: ohm3,
          observations: obs,
          latitude: lat,
          longitude: lng,
        ),
      );
    }
    return out;
  }

  // ----------------- helpers -----------------

  static ex.Data? _cell(List<ex.Data?> row, int? idx) =>
      (idx == null || idx < 0 || idx >= row.length) ? null : row[idx];

  static String _cellText(ex.Data? c) {
    final v = c?.value;
    if (v == null) return '';
    return v.toString().trim();
  }

  static double? _toDouble(ex.Data? c) {
    final v = c?.value;
    if (v == null) return null;
    final s = v.toString().replaceAll(',', '.').trim();
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  static DateTime? _toDateTime(ex.Data? c) {
    final v = c?.value;
    if (v == null) return null;

    final s = v.toString().trim();

    // 1) Intento directo (incluye ISO)
    if (s.isNotEmpty) {
      final iso = DateTime.tryParse(s);
      if (iso != null) return iso;

      // dd/mm/yyyy o d-m-yy
      final m = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})$').firstMatch(s);
      if (m != null) {
        final d = int.parse(m.group(1)!);
        final mo = int.parse(m.group(2)!);
        final y = int.parse(m.group(3)!);
        final year = y < 100 ? (2000 + y) : y;
        return DateTime(year, mo, d);
      }
    }

    // 2) Ãƒâ€šÃ‚ÂSerial Excel?
    final asNum = double.tryParse(s);
    if (asNum != null) {
      // Base serial Excel: 1899-12-30
      final base = DateTime(1899, 12, 30);
      final days = asNum.floor();
      final frac = asNum - days;
      final seconds = (frac * 86400).round();
      return base.add(Duration(days: days, seconds: seconds));
    }

    return null;
  }

  static String _fallbackProgresiva(int rowIndex) =>
      'PK ${rowIndex.toString().padLeft(3, '0')}';

  static String _normHeader(String s) {
    final t = s.toLowerCase().trim();
    final noAcc = t
        .replaceAll('ÃƒÆ’Ã‚Â¡', 'a')
        .replaceAll('ÃƒÆ’Ã‚Â©', 'e')
        .replaceAll('ÃƒÆ’Ã‚Â­', 'i')
        .replaceAll('ÃƒÆ’Ã‚Â³', 'o')
        .replaceAll('ÃƒÆ’Ã‚Âº', 'u')
        .replaceAll('ÃƒÆ’Ã‚Â¼', 'u')
        .replaceAll('ÃƒÆ’Ã‚Â±', 'n');
    return noAcc.replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  /// Mapeo flexible de encabezados ? claves internas
  static Map<String, int> _buildHeaderMap(List<String> headers) {
    int? find(Set<String> keys) {
      for (var i = 0; i < headers.length; i++) {
        final h = headers[i];
        if (keys.contains(h)) return i;
      }
      return null;
    }

    return <String, int?>{
      // Coordenadas
      'lat': find({'lat', 'latitude', 'latitud'}),
      'lng': find({'lng', 'lon', 'long', 'longitud', 'longitude'}),
      // Campos
      'progresiva': find({'progresiva', 'prog', 'pk', 'cadena', 'tramo'}),
      'ohm1': find({'1m', 'ohm1m', 'ohm1', 'res1m', 'resistencia1m'}),
      'ohm3': find({'3m', 'ohm3m', 'ohm3', 'res3m', 'resistencia3m'}),
      'obs': find({'obs', 'observaciones', 'nota', 'notas', 'comentario', 'comentarios'}),
      'fecha': find({'fecha', 'date', 'fechamedicion', 'datetime'}),
    }.map((k, v) => MapEntry(k, v ?? -1));
  }
}
