// lib/providers/settings_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final settingsServiceProvider = Provider<SettingsService>((_) => SettingsService());

class SettingsService {
  static const _kDefaultEmailKey = 'default_email';

  SharedPreferences? _sp;
  Future<SharedPreferences> get _prefs async =>
      _sp ??= await SharedPreferences.getInstance();

  Future<String?> getDefaultEmail() async {
    final sp = await _prefs;
    return sp.getString(_kDefaultEmailKey);
  }

  Future<void> saveDefaultEmail(String? email) async {
    final sp = await _prefs;
    if (email == null || email.trim().isEmpty) {
      await sp.remove(_kDefaultEmailKey);
    } else {
      await sp.setString(_kDefaultEmailKey, email.trim());
    }
  }

  static String _latKey(String id) => 'sheet_${id}_lat';
  static String _lngKey(String id) => 'sheet_${id}_lng';
  static String _aiKey(String id) => 'sheet_${id}_ai_enabled';

  Future<({double? lat, double? lng})> getLocation(String id) async {
    final sp = await _prefs;
    return (lat: sp.getDouble(_latKey(id)), lng: sp.getDouble(_lngKey(id)));
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

  Future<void> setAiEnabled(String id, bool value) async {
    final sp = await _prefs;
    await sp.setBool(_aiKey(id), value);
  }
}
