// lib/services/quick_mail_service.dart
import 'package:flutter/services.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:share_plus/share_plus.dart';

import '../models/measurement.dart';
import '../models/sheet_meta.dart';
import 'xlsx_export_service.dart';

class QuickMailService {
  const QuickMailService();

  Future<void> sendSheet({
    required SheetMeta meta,
    required List<Measurement> rows,
    required String toEmail,
  }) async {
    final svc = XlsxExportService();

    // buildFile ahora requiere sheetId (y opcionalmente lat/lng por defecto)
    final file = await svc.buildFile(
      sheetId: meta.id,
      title: meta.name.isEmpty ? 'Planilla' : meta.name,
      data: rows,
      defaultLat: meta.latitude,
      defaultLng: meta.longitude,
    );

    try {
      final email = Email(
        recipients: [toEmail],
        subject: 'Gridnote – ${meta.name}',
        body: 'Adjunto archivo generado con Gridnote para "${meta.name}".',
        attachmentPaths: [file.path],
        isHTML: false,
      );
      await FlutterEmailSender.send(email);
    } on PlatformException {
      await Share.shareXFiles(
        [
          XFile(
            file.path,
            mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          )
        ],
        subject: 'Gridnote – ${meta.name}',
        text: 'Adjunto archivo generado con Gridnote para "${meta.name}".',
      );
    }
  }
}
