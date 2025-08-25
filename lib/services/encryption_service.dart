import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncryptionService {
  EncryptionService._();
  static final instance = EncryptionService._();

  static const _kKeyName = 'gridnote_master_key_v1';
  final _algo = AesGcm.with256bits();
  final _secure = const FlutterSecureStorage();

  Future<SecretKey> _loadOrCreateKey() async {
    var b64 = await _secure.read(key: _kKeyName);
    if (b64 == null || b64.isEmpty) {
      final rnd = Random.secure();
      final keyBytes = Uint8List.fromList(List<int>.generate(32, (_) => rnd.nextInt(256)));
      b64 = base64.encode(keyBytes);
      await _secure.write(key: _kKeyName, value: b64);
    }
    return SecretKey(base64.decode(b64));
  }

  Future<Uint8List> encryptBytes(Uint8List plain) async {
    final key = await _loadOrCreateKey();
    final nonce = Uint8List(12)..setAll(0, List<int>.generate(12, (_) => Random.secure().nextInt(256)));
    final res = await _algo.encrypt(plain, secretKey: key, nonce: nonce);
    final map = {
      'n': base64.encode(nonce),
      'c': base64.encode(res.cipherText),
      'm': base64.encode(res.mac.bytes),
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(map)));
  }

  Future<Uint8List> decryptBytes(Uint8List enc) async {
    final key = await _loadOrCreateKey();
    final map = jsonDecode(utf8.decode(enc)) as Map<String, dynamic>;
    final nonce = base64.decode(map['n'] as String);
    final cipher = base64.decode(map['c'] as String);
    final mac = Mac(base64.decode(map['m'] as String));
    final res = await _algo.decrypt(
      SecretBox(cipher, nonce: nonce, mac: mac),
      secretKey: key,
    );
    return Uint8List.fromList(res);
  }
}
