import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../models/measurement.dart';
import '../models/sheet_meta.dart';
import 'xlsx_export_service.dart';
import 'notification_service.dart'; // ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ nombre correcto

class AutoExportService {
  static String _sanitize(String s) =>
      s.replaceAll(RegExp(r'[<>:"/\\|?*\n\r]+'), '_').trim();

  /// Genera el XLSX y lo copia a almacenamiento externo de la app:
  /// ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¦/Android/data/<package>/files/Gridnote/
  static Future<File> exportSheet({
    required SheetMeta meta,
    required List<Measurement> data,
    double? defaultLat,
    double? defaultLng,
  }) async {
    final tmp = await XlsxExportService().buildFile(
      sheetId: meta.id,
      title: meta.name,
      data: data,
      defaultLat: defaultLat,
      defaultLng: defaultLng,
    );

    final extDir = await getExternalStorageDirectory(); // app-specific
    final outDir = Directory('${extDir!.path}/Gridnote');
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final fname = '${_sanitize(meta.name)}_$stamp.xlsx';
    final out = File('${outDir.path}/$fname');
    await tmp.copy(out.path);
    return out;
  }

  static Future<void> exportAndNotify({
    required SheetMeta meta,
    required List<Measurement> data,
    double? defaultLat,
    double? defaultLng,
  }) async {
    final f = await exportSheet(
      meta: meta,
      data: data,
      defaultLat: defaultLat,
      defaultLng: defaultLng,
    );

    await NotificationService.instance.showSavedSheet( // ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ clase/mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©todo correctos
      title: 'Planilla exportada',
      body: 'Guardada en: ${f.path.split('/Android/').last}',
      filePath: f.path,
    );
  }
}
