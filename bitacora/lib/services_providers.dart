import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

final remoteConfigProvider = FutureProvider<FirebaseRemoteConfig>((ref) async {
  final rc = FirebaseRemoteConfig.instance;
  await rc.setConfigSettings(const RemoteConfigSettings(
    fetchTimeout: Duration(seconds: 10),
    minimumFetchInterval: Duration(hours: 1),
  ));
  await rc.fetchAndActivate();
  return rc;
});

final allowedEmailsProvider = FutureProvider<List<String>>((ref) async {
  final rc = await ref.watch(remoteConfigProvider.future);
  try {
    final raw = rc.getString('allowed_emails');
    if (raw.isEmpty) return const <String>[];
    if (raw.trim().startsWith('[')) {
      final List<dynamic> list = jsonDecode(raw);
      return list.cast<String>().map((e) => e.toLowerCase()).toSet().toList();
    }
    return raw
        .split(RegExp(r'[;,\s]+'))
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  } catch (e) {
    debugPrint('RC parse error: $e');
    return const <String>[];
  }
});
