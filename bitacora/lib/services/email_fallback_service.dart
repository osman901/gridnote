// lib/services/email_fallback_service.dart
import 'dart:io';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:share_plus/share_plus.dart';

class EmailFallbackService {
  const EmailFallbackService();

  Future<void> sendXlsx({
    required File file,
    String subject = 'Bitácora XLSX',
    String body = 'Adjunto XLSX.',
    List<String> to = const [],
  }) async {
    // 1) Intento con flutter_email_sender (adjunto real)
    try {
      final email = Email(
        subject: subject,
        body: body,
        recipients: to,
        attachmentPaths: [file.path],
        isHTML: false,
      );
      await FlutterEmailSender.send(email);
      return;
    } catch (_) {
      // continúa al fallback
    }

    // 2) Fallback: compartir el archivo con Share (elige Gmail/Outlook/etc)
    await Share.shareXFiles(
      [
        XFile(
          file.path,
          mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      ],
      subject: subject,
      text: body,
    );
  }
}

