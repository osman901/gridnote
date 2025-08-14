import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import '../models/measurement.dart';
import '../models/sheet_meta.dart';
import 'excel_export_service.dart';

class QuickMailService {
  final _excel = ExcelExportService();

  Future<void> sendSheet({
    required SheetMeta meta,
    required List<Measurement> rows,
    required String toEmail,
  }) async {
    final bytes = await _excel.buildExcelBytes(rows: rows, meta: meta);
    final dir = await getTemporaryDirectory();
    final safeName = (meta.name.isEmpty ? 'planilla' : meta.name)
        .replaceAll(RegExp(r'[^\w\-\ ]+'), '_');
    final path = '${dir.path}/$safeName-${meta.id}.xlsx';
    final file = File(path); await file.writeAsBytes(bytes, flush: true);

    try {
      final email = Email(
        recipients: [toEmail],
        subject: 'Planilla ${meta.name}',
        body: 'Te envío la planilla ${meta.name}.',
        attachmentPaths: [path],
        isHTML: false,
      );
      await FlutterEmailSender.send(email);
    } on PlatformException {
      // Fallback: hoja de compartir
      await Share.shareXFiles(
        [XFile(path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
        subject: 'Planilla ${meta.name}',
        text: 'Planilla ${meta.name}',
      );
    }
  }
}
