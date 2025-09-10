// lib/services_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'service_locator.dart' show getIt; // asegurate de llamar setupServiceLocator() en main()

// Fuentes de allowed emails (sin Firebase): .env / SharedPreferences
import 'remote_config_providers.dart' show allowedEmailsProvider;

// Servicios varios
import 'services/xlsx_export_service.dart';
import 'services/csv_export_service.dart';
import 'services/pdf_export_service.dart';
import 'services/ocr_table_import_service.dart';
import 'services/suggest_service.dart';

/// SharedPreferences desde getIt
final sharedPrefsProvider = Provider<SharedPreferences>(
      (ref) => getIt<SharedPreferences>(),
);

/// Allowed emails (re-export del provider sin Firebase)
final allowedEmailsProviderAlias = allowedEmailsProvider;

/// Proveedores de servicios registrados en getIt
final xlsxExportServiceProvider = Provider<XlsxExportService>(
      (ref) => getIt<XlsxExportService>(),
);

final csvExportServiceProvider = Provider<CsvExportService>(
      (ref) => getIt<CsvExportService>(),
);

final pdfExportServiceProvider = Provider<PdfExportService>(
      (ref) => getIt<PdfExportService>(),
);

final ocrTableImportServiceProvider = Provider<OcrTableImportService>(
      (ref) => getIt<OcrTableImportService>(),
);

final suggestServiceProvider = Provider<SuggestService>(
      (ref) => getIt<SuggestService>(),
);
