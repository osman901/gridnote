// lib/services/service_locator.dart
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import './suggest_service.dart';
import './ocr_table_import_service.dart';
import './xlsx_export_service.dart';
import './csv_export_service.dart';
import './pdf_export_service.dart';
import './audit_log_service.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Recursos async
  getIt.registerSingletonAsync<SharedPreferences>(
        () async => SharedPreferences.getInstance(),
  );

  // Servicios ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã¢â‚¬Å“purosÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â
  getIt.registerLazySingleton<SuggestService>(() => SuggestService()..load());
  getIt.registerLazySingleton<OcrTableImportService>(
        () => OcrTableImportService(),
  );
  getIt.registerLazySingleton<XlsxExportService>(() => XlsxExportService());
  getIt.registerLazySingleton<CsvExportService>(() => CsvExportService());
  getIt.registerLazySingleton<PdfExportService>(() => PdfExportService());

  // Con parÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡metros
  getIt.registerFactoryParam<AuditLogService, String, void>(
        (sheetId, _) => AuditLogService(sheetId),
  );

  await getIt.allReady();
}
