// lib/services/export_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Utilidades de exportación/compartido local (sin backend).
class ExportService {
  /// Comparte un XLSX rápidamente desde bytes.
  static Future<bool> shareExcelQuick({
    required BuildContext context,
    required List<int> bytes,
    required String suggestedName,
  }) async {
    try {
      final tmp = await _writeTemp(bytes, suggestedName);
      final xfile = XFile(
        tmp.path,
        mimeType:
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      await Share.shareXFiles(
        [xfile],
        subject: 'Gridnote – Reporte XLSX',
        text: 'Adjunto Excel generado desde Gridnote.',
      );
      return true;
    } catch (e, st) {
      // Log técnico para depuración
      debugPrint('ExportService.shareExcelQuick error: $e\n$st');

      // Feedback claro al usuario
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo compartir el archivo. Intentalo de nuevo.'),
        ),
      );
      return false;
    }
  }

  /// Sanea nombres de archivo para sistemas de archivos comunes (Windows/macOS/Linux/Android/iOS).
  static String sanitizeFileName(String input) {
    var s = input.trim();

    // Si no hay nombre, generamos uno por timestamp.
    if (s.isEmpty) {
      return 'gridnote_${DateTime.now().millisecondsSinceEpoch}';
    }

    // Reemplaza caracteres inválidos: \ / : * ? " < > |
    s = s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    // Colapsa espacios repetidos y recorta.
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Evita nombres excesivamente largos.
    if (s.length > 120) {
      s = s.substring(0, 120);
    }

    // Evita nombres reservados o vacíos tras saneamiento.
    if (s.isEmpty) {
      s = 'gridnote_${DateTime.now().millisecondsSinceEpoch}';
    }
    return s;
  }

  /// Escribe los bytes en un archivo temporal con nombre seguro.
  static Future<File> _writeTemp(List<int> bytes, String name) async {
    final dir = await getTemporaryDirectory();

    final base = sanitizeFileName(name);
    final finalName = base.toLowerCase().endsWith('.xlsx') ? base : '$base.xlsx';
    final filePath = p.join(dir.path, finalName);

    final f = File(filePath);
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }
}
