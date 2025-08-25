// lib/services/service_locator.dart
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/suggest_service.dart';
import '../services/ocr_table_import_service.dart';
import '../services/xlsx_export_service.dart';
import '../services/csv_export_service.dart';
import '../services/pdf_export_service.dart';
import '../services/audit_log_service.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Recursos async
  getIt.registerSingletonAsync<SharedPreferences>(
        () async => await SharedPreferences.getInstance(),
  );

  // Servicios “puros”
  getIt.registerLazySingleton<SuggestService>(() => SuggestService()..load());
  getIt.registerLazySingleton<OcrTableImportService>(() => OcrTableImportService());
  getIt.registerLazySingleton<XlsxExportService>(() => XlsxExportService());
  getIt.registerLazySingleton<CsvExportService>(() => CsvExportService());
  getIt.registerLazySingleton<PdfExportService>(() => PdfExportService());

  // Con parámetros
  getIt.registerFactoryParam<AuditLogService, String, void>(
        (sheetId, _) => AuditLogService(sheetId),
  );

  await getIt.allReady();
}
