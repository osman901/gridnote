import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'email_share_service.dart';

/// Intenta enviar (devuelve true si pudo).
/// Si no hay conectividad, devolvÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©s false y el caller lo encola en Outbox.
class SendReportService {
  SendReportService._();
  static final SendReportService instance = SendReportService._();

  final EmailShareService _email = const EmailShareService();

  Future<bool> trySendExcelFromPath({
    required String path,
    String? filename,
    String? to,
    String? subject,
    String? text,
  }) async {
    if (!await _isOnline()) return false;
    try {
      await _email.sendWithFallback(
        to: to ?? '',
        subject: subject ?? (filename ?? 'Planilla'),
        body: text ?? '',
        attachment: File(path),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> trySendPdfFromPath({
    required String path,
    String? filename,
    String? to,
    String? subject,
    String? text,
  }) async {
    if (!await _isOnline()) return false;
    try {
      await _email.sendWithFallback(
        to: to ?? '',
        subject: subject ?? (filename ?? 'Reporte'),
        body: text ?? '',
        attachment: File(path),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _isOnline() async {
    final res = await Connectivity().checkConnectivity();
    return res.isNotEmpty && !res.contains(ConnectivityResult.none);
  }
}
