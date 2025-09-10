import 'package:shared_preferences/shared_preferences.dart';

class StoredLocation {
  final double? lat;
  final double? lng;
  const StoredLocation({this.lat, this.lng});
}

class StoredSession {
  final int? rowIndex;
  final double? scrollOffset;
  const StoredSession({this.rowIndex, this.scrollOffset});
}

class SettingsService {
  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  // -------- Email por defecto --------
  static const _kDefaultEmailKey = 'default_email';

  Future<String?> getDefaultEmail() async {
    final sp = await _prefs;
    return sp.getString(_kDefaultEmailKey);
  }

  Future<void> saveDefaultEmail(String? email) async {
    final sp = await _prefs;
    final v = email?.trim();
    if (v == null || v.isEmpty) {
      await sp.remove(_kDefaultEmailKey);
    } else {
      await sp.setString(_kDefaultEmailKey, v);
    }
  }

  // -------- UbicaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n por planilla --------
  String _latKey(String id) => 'sheet_${id}_lat';
  String _lngKey(String id) => 'sheet_${id}_lng';

  Future<StoredLocation> getLocation(String id) async {
    final sp = await _prefs;
    return StoredLocation(
      lat: sp.getDouble(_latKey(id)),
      lng: sp.getDouble(_lngKey(id)),
    );
  }

  Future<void> saveLocation(String id, double lat, double lng) async {
    final sp = await _prefs;
    await sp.setDouble(_latKey(id), lat);
    await sp.setDouble(_lngKey(id), lng);
  }

  // -------- IA habilitada por planilla --------
  String _aiKey(String id) => 'sheet_${id}_ai_enabled';

  Future<bool> getAiEnabled(String id) async {
    final sp = await _prefs;
    return sp.getBool(_aiKey(id)) ?? true;
  }

  Future<void> setAiEnabled(String id, bool enabled) async {
    final sp = await _prefs;
    await sp.setBool(_aiKey(id), enabled);
  }

  // -------- SesiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n de grilla (restaurar al volver) --------
  String _rowKey(String id) => 'sheet_${id}_last_row';
  String _offKey(String id) => 'sheet_${id}_scroll_off';

  Future<void> saveSheetSession(
      String id, {
        int? rowIndex,
        double? scrollOffset,
      }) async {
    final sp = await _prefs;
    if (rowIndex != null) await sp.setInt(_rowKey(id), rowIndex);
    if (scrollOffset != null) await sp.setDouble(_offKey(id), scrollOffset);
  }

  Future<StoredSession> getSheetSession(String id) async {
    final sp = await _prefs;
    return StoredSession(
      rowIndex: sp.getInt(_rowKey(id)),
      scrollOffset: sp.getDouble(_offKey(id)),
    );
  }
}
