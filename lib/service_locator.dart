// lib/service_locator.dart
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/xlsx_export_service.dart';
import 'services/csv_export_service.dart';
import 'services/pdf_export_service.dart';
import 'services/ocr_table_import_service.dart';
import 'services/suggest_service.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Core async singletons
  final sp = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sp);

  // Services
  getIt.registerLazySingleton<XlsxExportService>(() => XlsxExportService());
  getIt.registerLazySingleton<CsvExportService>(() => CsvExportService());
  getIt.registerLazySingleton<PdfExportService>(() => PdfExportService());
  getIt.registerLazySingleton<OcrTableImportService>(() => OcrTableImportService());
  getIt.registerLazySingleton<SuggestService>(() => SuggestService());
}
