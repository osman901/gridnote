class SendReportService {
  SendReportService._();
  static final SendReportService instance = SendReportService._();

  /// Debe intentar enviar el XLSX en `path` y devolver true si lo logró.
  Future<bool> trySendExcelFromPath({
    required String path,
    required String filename,
    String? to,
    String? subject,
    String? text,
  }) async {
    // TODO: implementar envío real (SMTP/API/Share/etc.)
    return false;
  }

  /// Debe intentar enviar el PDF en `path` y devolver true si lo logró.
  Future<bool> trySendPdfFromPath({
    required String path,
    required String filename,
    String? to,
    String? subject,
    String? text,
  }) async {
    // TODO: implementar envío real (SMTP/API/Share/etc.)
    return false;
  }
}
