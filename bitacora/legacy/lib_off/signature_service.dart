import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignatureService {
  static const _kSecret = 'sign_secret_v1';

  static Future<void> setSecret(String s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kSecret, s);
  }

  static Future<String> getSecret() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kSecret) ?? 'gridnote_default_secret_change_me';
  }

  static Future<String> hmacOf(String payload) async {
    final secret = await getSecret();
    final mac = Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(payload));
    return mac.toString();
  }
}
