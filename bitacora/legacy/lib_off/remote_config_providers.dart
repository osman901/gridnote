// lib/remote_config_providers.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' as dotenv;

/// Parsea correos desde JSON (["a@x.com","b@y.com"]) o CSV ("a@x.com,b@y.com")
List<String> _parseAllowedEmails(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const <String>[];
  try {
    if (raw.trimLeft().startsWith('[')) {
      final list = (jsonDecode(raw) as List).cast<String>();
      return list.map((e) => e.toLowerCase()).toSet().toList();
    }
    return raw
        .split(RegExp(r'[;,\s]+'))
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  } catch (e) {
    debugPrint('AllowedEmails parse error: $e');
    return const <String>[];
  }
}

/// Fuente: .env (ALLOWED_EMAILS) con fallback a SharedPreferences('allowed_emails')
final allowedEmailsProvider = FutureProvider<List<String>>((ref) async {
  // Asegurate de llamar en main(): await dotenv.load(fileName: ".env");
  String? raw = dotenv.dotenv.env['ALLOWED_EMAILS'];
  raw ??= (await SharedPreferences.getInstance()).getString('allowed_emails');
  return _parseAllowedEmails(raw);
});
