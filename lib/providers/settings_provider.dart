import 'package:shared_preferences/shared_preferences.dart';

class StoredLocation {
  final double? lat;
  final double? lng;
  const StoredLocation({this.lat, this.lng});
}

class SettingsService {
  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<String?> getDefaultEmail() async {
    final sp = await _prefs;
    return sp.getString('default_email');
  }

  Future<void> saveDefaultEmail(String? email) async {
    final sp = await _prefs;
    final v = email?.trim();
    if (v == null || v.isEmpty) {
      await sp.remove('default_email');
    } else {
      await sp.setString('default_email', v);
    }
  }

  String _latKey(String id) => 'sheet_${id}_lat';
  String _lngKey(String id) => 'sheet_${id}_lng';
  String _aiKey (String id) => 'sheet_${id}_ai_enabled';

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

  Future<bool> getAiEnabled(String id) async {
    final sp = await _prefs;
    return sp.getBool(_aiKey(id)) ?? true;
  }

  Future<void> setAiEnabled(String id, bool enabled) async {
    final sp = await _prefs;
    await sp.setBool(_aiKey(id), enabled);
  }
}
