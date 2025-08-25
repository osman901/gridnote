import 'dart:io';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class EmailShareService {
  const EmailShareService(); // <- ahora es const

  Future<void> sendWithFallback({
    required String to,
    required String subject,
    required String body,
    required File attachment,
  }) async {
    // 1) App de correo nativa
    try {
      final mail = Email(
        recipients: [to],
        subject: subject,
        body: body,
        isHTML: false,
        attachmentPaths: [attachment.path],
      );
      await FlutterEmailSender.send(mail);
      return;
    } catch (_) {
      // ignore
    }

    // 2) mailto:
    try {
      final uri = Uri(
        scheme: 'mailto',
        path: to,
        queryParameters: {'subject': subject, 'body': body},
      );
      if (await canLaunchUrl(uri)) {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (ok) return;
      }
    } catch (_) {
      // ignore
    }

    // 3) Share sheet
    await Share.shareXFiles(
      [
        XFile(
          attachment.path,
          mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        )
      ],
      subject: subject,
      text: body,
    );
  }
}
