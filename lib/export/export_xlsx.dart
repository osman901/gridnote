import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Export universal a CSV que abre perfecto en Excel/Google Sheets.
/// [rows] = lista de mapas homogéneos {columna: valor}. El orden de columnas se
/// toma de [columns] si se provee; si no, de las keys de la primera fila.
class ExportXlsx {
  static Future<File> toCsv({
    required String fileName, // sin extensión
    required List<Map<String, dynamic>> rows,
    List<String>? columns,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName.csv');

    if (rows.isEmpty) {
      await file.writeAsString('');
      return file;
    }

    final cols = columns ?? rows.first.keys.toList();
    final sink = file.openWrite();
    // Header
    sink.writeln(_csvLine(cols));
    // Rows
    for (final r in rows) {
      sink.writeln(_csvLine(cols.map((c) => r[c]).toList()));
    }
    await sink.flush();
    await sink.close();
    return file;
  }

  static String _csvLine(Iterable values) {
    return values.map((v) {
      final s = (v ?? '').toString();
      final needsQuote = s.contains(',') || s.contains('"') || s.contains('\n');
      final esc = s.replaceAll('"', '""');
      return needsQuote ? '"$esc"' : esc;
    }).join(',');
  }
}
