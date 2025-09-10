// lib/services/quick_mail_service.dart
import 'package:flutter/services.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:share_plus/share_plus.dart';

import '../models/measurement.dart';
import '../models/sheet_meta.dart';
import 'export_xlsx_service.dart'; // ✅ usa tu servicio real

class QuickMailService {
  const QuickMailService();

  /// Exporta una planilla mínima a XLSX y la envía por email (o comparte si no hay cliente de email).
  ///
  /// Nota: Para compatibilidad rápida y evitar dependencias a modelos internos,
  /// este export genera una sola columna con el `toString()` de cada Measurement.
  /// Más adelante podés mapear campos específicos (título, nota, lat, lng, etc.).
  Future<void> sendSheet({
    required SheetMeta meta,
    required List<Measurement> rows,
    required String toEmail,
  }) async {
    // Construcción mínima de datos para XLSX
    final headers = <String>['Dato'];
    final data = rows.map((m) => <String>[m.toString()]).toList();

    final svc = const ExportXlsxService();
    final file = await svc.exportToXlsx(
      headers: headers,
      rows: data,
      sheetName: (meta.name.isEmpty ? 'Planilla' : meta.name),
      autoOpen: false,
    );

    try {
      final email = Email(
        recipients: [toEmail],
        subject: 'Gridnote — ${meta.name}',
        body: 'Adjunto archivo generado con Gridnote para "${meta.name}".',
        attachmentPaths: [file.path],
        isHTML: false,
      );
      await FlutterEmailSender.send(email);
    } on PlatformException {
      // Fallback a compartir si no hay cliente de email disponible
      await Share.shareXFiles(
        [
          XFile(
            file.path,
            mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        subject: 'Gridnote — ${meta.name}',
        text: 'Adjunto archivo generado con Gridnote para "${meta.name}".',
      );
    }
  }
}
