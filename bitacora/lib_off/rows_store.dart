import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

class RowsStore {
  RowsStore._();
  static final instance = RowsStore._();

  static String _boxName(String sheetId) => 'rows_$sheetId';

  Future<void> initSheetBox(String sheetId) async {
    if (!Hive.isBoxOpen(_boxName(sheetId))) {
      await Hive.openBox<String>(_boxName(sheetId));
    }
  }

  Future<void> saveRows(String sheetId, List<Map<String, dynamic>> rows) async {
    final box = Hive.box<String>(_boxName(sheetId));
    await box.put('data', jsonEncode(rows)); // ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºnico registro ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã¢â‚¬Å“dataÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â
  }

  /// Devuelve [{row:1, ohm1m:..., ohm3m:..., obs:'', date:'...', latitude:..., longitude:...}]
  Future<List<Map<String, dynamic>>> loadRows(String sheetId) async {
    final box = Hive.box<String>(_boxName(sheetId));
    final raw = box.get('data');
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .cast<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
