// lib/services/settings_service.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio centralizado para preferencias de envÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­o.
/// - endpoint (URL de API)
/// - defaultEmail (destino rÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡pido para Excel)
class SettingsService extends ChangeNotifier {
// ---- Singleton ----
  SettingsService._();
  static final SettingsService instance = SettingsService._();

// ---- Claves de SharedPreferences ----
  static const String _kEndpointKey = 'send_endpoint';
  static const String _kDefaultEmailKey = 'send_default_email';

  SharedPreferences? _sp;
  String? _endpoint;
  String? _defaultEmail;

  /// Cargar en memoria (idempotente).
  Future<void> init() async {
    if (_sp != null) return;
    _sp = await SharedPreferences.getInstance();
    _endpoint = _sp!.getString(_kEndpointKey);
    _defaultEmail = _sp!.getString(_kDefaultEmailKey);
  }

  /// Snapshot rÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡pido (asegura init).
  Future<SettingsSnapshot> snapshot() async {
    await init();
    return SettingsSnapshot(
      endpoint: _endpoint,
      defaultEmail: _defaultEmail,
    );
  }

// ---- Getters actuales en memoria (pueden ser null) ----
  String? get endpoint => _endpoint;
  String? get defaultEmail => _defaultEmail;

  bool get hasQuickSendTarget =>
      (_endpoint?.isNotEmpty ?? false) || (_defaultEmail?.isNotEmpty ?? false);

// ---- Setters (persisten y notifican) ----
  Future<void> setEndpoint(String? value) async {
    await init();
    final v = _normalize(value);
    if (v == null) {
      await _sp!.remove(_kEndpointKey);
    } else {
      await _sp!.setString(_kEndpointKey, v);
    }
    _endpoint = v;
    notifyListeners();
  }

  Future<void> setDefaultEmail(String? value) async {
    await init();
    final v = _normalize(value);
    if (v == null) {
      await _sp!.remove(_kDefaultEmailKey);
    } else {
      await _sp!.setString(_kDefaultEmailKey, v);
    }
    _defaultEmail = v;
    notifyListeners();
  }

  /// Guardado mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºltiple atÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³mico.
  Future<void> setFrom({
    String? endpoint,
    String? defaultEmail,
  }) async {
    await init();
    if (endpoint != null) await setEndpoint(endpoint);
    if (defaultEmail != null) await setDefaultEmail(defaultEmail);
  }

  /// Borrar todo lo relacionado al envÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­o.
  Future<void> clear() async {
    await init();
    await _sp!.remove(_kEndpointKey);
    await _sp!.remove(_kDefaultEmailKey);
    _endpoint = null;
    _defaultEmail = null;
    notifyListeners();
  }

// ----------------- Validadores reutilizables -----------------

  /// Valida email. Devuelve `null` cuando es vÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡lido.
  static String? emailValidator(String? value) {
    final s = value?.trim() ?? '';
    if (s.isEmpty) return 'Ingrese un email';
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!re.hasMatch(s)) return 'Email invÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡lido';
    return null;
  }

  /// Valida URL http/https. Devuelve `null` cuando es vÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡lida.
  static String? urlValidator(String? value) {
    final s = value?.trim() ?? '';
    if (s.isEmpty) return 'Ingrese la URL';
    final uri = Uri.tryParse(s);
    if (uri == null ||
        uri.host.isEmpty ||
        !(uri.isScheme('http') || uri.isScheme('https'))) {
      return 'URL invÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡lida (use http/https)';
    }
    return null;
  }

// ----------------- Helpers internos -----------------

  String? _normalize(String? v) {
    final s = v?.trim() ?? '';
    return s.isEmpty ? null : s;
  }
}

/// Estructura inmutable para lectura fÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡cil.
class SettingsSnapshot {
  const SettingsSnapshot({
    required this.endpoint,
    required this.defaultEmail,
  });

  final String? endpoint;
  final String? defaultEmail;

  SettingsSnapshot copyWith({
    String? endpoint,
    String? defaultEmail,
  }) =>
      SettingsSnapshot(
        endpoint: endpoint ?? this.endpoint,
        defaultEmail: defaultEmail ?? this.defaultEmail,
      );
}
