// lib/services/license_manager.dart
// Ed25519 offline + trial 30 días.

import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

@immutable
class LicenseStatus {
  final bool allowed;
  final bool hasValidLicense;
  final DateTime? expiresAtUtc;
  final int daysLeft;
  final String reason;
  const LicenseStatus({
    required this.allowed,
    required this.hasValidLicense,
    required this.expiresAtUtc,
    required this.daysLeft,
    required this.reason,
  });
}

class LicenseManager {
  LicenseManager({
    String? publicKeyBase64,
    Duration? trialPeriod,
    this.serverBaseUrl,
  })  : _publicKeyBase64 = publicKeyBase64 ?? _kSamplePublicKeyBase64,
        _trial = trialPeriod ?? const Duration(days: 30);

  final String _publicKeyBase64;
  final Duration _trial;
  final Uri? serverBaseUrl;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true, resetOnError: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _kKeyInstallId = 'gn_install_id';
  static const _kKeyTrialStartMs = 'gn_trial_start_ms';
  static const _kKeyLicenseToken = 'gn_license_token';
  static const _kKeyLastSeenUtcMs = 'gn_last_seen_utc_ms';

  // Reemplazá por tu clave pública real (base64 estándar, 32 bytes).
  static const _kSamplePublicKeyBase64 =
      '5v4Q3u9VY0b4a+f7j6xq9oSg2b3b6q8mQk2fG+o4q1U=';

  Future<void> initialize() async {
    var installId = await _storage.read(key: _kKeyInstallId);
    if (installId == null || installId.isEmpty) {
      installId = const Uuid().v4();
      await _storage.write(key: _kKeyInstallId, value: installId);
    }
    final trialStart = await _storage.read(key: _kKeyTrialStartMs);
    if (trialStart == null) {
      final nowUtc = await _nowUtc();
      await _storage.write(key: _kKeyTrialStartMs, value: nowUtc.millisecondsSinceEpoch.toString());
      await _storage.write(key: _kKeyLastSeenUtcMs, value: nowUtc.millisecondsSinceEpoch.toString());
    }
  }

  Future<String> get installId async => (await _storage.read(key: _kKeyInstallId)) ?? '';

  Future<DateTime> _nowUtc() async {
    if (serverBaseUrl != null) {
      try {
        final r = await http.get(serverBaseUrl!.resolve('/time')).timeout(const Duration(seconds: 5));
        if (r.statusCode == 200) {
          final s = json.decode(r.body) as Map<String, dynamic>;
          return DateTime.parse((s['utc'] as String)).toUtc();
        }
      } catch (_) {}
    }
    return DateTime.now().toUtc();
  }

  Future<LicenseStatus> status() async {
    final now = await _nowUtc();

    // Anti-retroceso de reloj
    final lastSeenStr = await _storage.read(key: _kKeyLastSeenUtcMs);
    if (lastSeenStr != null) {
      final lastSeen = DateTime.fromMillisecondsSinceEpoch(int.tryParse(lastSeenStr) ?? 0, isUtc: true);
      if (now.isBefore(lastSeen.subtract(const Duration(hours: 48)))) {
        return const LicenseStatus(
          allowed: false,
          hasValidLicense: false,
          expiresAtUtc: null,
          daysLeft: 0,
          reason: 'Reloj alterado. Conectá a internet para validar hora.',
        );
      }
    }
    await _storage.write(key: _kKeyLastSeenUtcMs, value: now.millisecondsSinceEpoch.toString());

    // Licencia
    final token = await _storage.read(key: _kKeyLicenseToken);
    if (token != null && token.isNotEmpty) {
      final lic = await _validateToken(token);
      if (lic.$1) {
        final exp = lic.$2!;
        final days = _daysLeft(now, exp);
        final allowed = now.isBefore(exp);
        return LicenseStatus(
          allowed: allowed,
          hasValidLicense: true,
          expiresAtUtc: exp,
          daysLeft: allowed ? days : 0,
          reason: allowed ? 'Licencia activa' : 'Licencia vencida',
        );
      }
    }

    // Trial
    final trialStartStr = await _storage.read(key: _kKeyTrialStartMs);
    final start = DateTime.fromMillisecondsSinceEpoch(int.tryParse(trialStartStr ?? '') ?? 0, isUtc: true);
    final end = start.add(_trial);
    final allowed = now.isBefore(end);
    final days = _daysLeft(now, end);

    return LicenseStatus(
      allowed: allowed,
      hasValidLicense: false,
      expiresAtUtc: end,
      daysLeft: allowed ? days : 0,
      reason: allowed ? 'Prueba activa' : 'Prueba vencida',
    );
  }

  int _daysLeft(DateTime now, DateTime end) {
    final diff = end.difference(now);
    final d = diff.inDays;
    if (d >= 1) return d;
    return diff.isNegative ? 0 : 1;
  }

  Future<(bool, DateTime?)> _validateToken(String token) async {
    try {
      final parts = token.split('.');
      if (parts.length != 2) return (false, null);
      final payload = base64Url.decode(_padB64(parts[0]));
      final sigBytes = base64Url.decode(_padB64(parts[1]));

      final map = json.decode(utf8.decode(payload)) as Map<String, dynamic>;
      final expIso = (map['exp'] as String?) ?? '';
      final device = (map['device'] as String?) ?? '*';

      final pkBytes = base64Decode(_publicKeyBase64);
      final publicKey = SimplePublicKey(pkBytes, type: KeyPairType.ed25519);
      final ok = await Ed25519().verify(
        payload,
        signature: Signature(sigBytes, publicKey: publicKey),
      );
      if (!ok) return (false, null);

      final myId = await installId;
      if (device != '*' && device != myId) return (false, null);

      final exp = DateTime.parse(expIso).toUtc();
      return (true, exp);
    } catch (_) {
      return (false, null);
    }
  }

  String _padB64(String s) {
    final r = s.replaceAll('-', '+').replaceAll('_', '/');
    final m = r.length % 4;
    if (m == 2) return '$r==';
    if (m == 3) return '$r=';
    if (m == 1) return '$r===';
    return r;
  }

  Future<bool> activate(String token) async {
    final res = await _validateToken(token);
    if (!res.$1) return false;
    await _storage.write(key: _kKeyLicenseToken, value: token);
    return true;
  }

  Future<void> clearLicense() async {
    await _storage.delete(key: _kKeyLicenseToken);
  }

  String humanStatus(LicenseStatus s) {
    final exp = s.expiresAtUtc?.toIso8601String() ?? 'N/D';
    return s.allowed
        ? '${s.hasValidLicense ? 'Licencia' : 'Prueba'}: ${s.daysLeft} días restantes • exp: $exp'
        : s.reason;
  }
}
