class ExcelExportException implements Exception {
  final String message;
  ExcelExportException(this.message);
  @override
  String toString() => 'ExcelExportException: $message';
}

class DriveInitializationException implements Exception {
  final String message;
  DriveInitializationException(this.message);
  @override
  String toString() => 'DriveInitializationException: $message';
}

class DriveAuthException implements Exception {
  final String message;
  DriveAuthException([this.message = 'Error de autenticaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n con Google Drive.']);
  @override
  String toString() => 'DriveAuthException: $message';
}

class DriveConnectivityException implements Exception {
  final String message;
  DriveConnectivityException([this.message = 'Sin conexiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n a internet.']);
  @override
  String toString() => 'DriveConnectivityException: $message';
}

class DriveQuotaException implements Exception {
  final String message;
  DriveQuotaException([this.message = 'Espacio insuficiente en Google Drive.']);
  @override
  String toString() => 'DriveQuotaException: $message';
}

class DriveUnknownException implements Exception {
  final String message;
  DriveUnknownException([this.message = 'Error inesperado en Google Drive.']);
  @override
  String toString() => 'DriveUnknownException: $message';
}
