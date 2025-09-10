// lib/services/secure_store.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;

import 'error_reporter.dart';

class SecureStore {
  SecureStore._();
  static final instance = SecureStore._();

  // VersiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n actual del formato cifrado
  static const _kHeaderCurrent = 'GN2';
  static const _kHeaderOld = 'GN1';

  static const _kKeyV2 = 'gridnote_master_key_v2';
  static const _kKeyV1 = 'gridnote_master_key_v1';

  final _rng = Random.secure();
  final _algo = AesGcm.with256bits();
  final _ffs = const FlutterSecureStorage();

  Future<SecretKey> _getOrCreateKey(String keyName) async {
    var b64 = await _ffs.read(key: keyName);
    if (b64 == null) {
      final raw = Uint8List(32);
      for (var i = 0; i < raw.length; i++) {
        raw[i] = _rng.nextInt(256);
      }
      b64 = base64UrlEncode(raw);
      await _ffs.write(key: keyName, value: b64);
    }
    return SecretKey(base64Url.decode(b64));
  }

  Future<SecretKey?> _tryGetKey(String keyName) async {
    final b64 = await _ffs.read(key: keyName);
    if (b64 == null) return null;
    return SecretKey(base64Url.decode(b64));
  }

  Future<Uint8List> encrypt(Uint8List plain) async {
    final key = await _getOrCreateKey(_kKeyV2);
    final nonce =
    Uint8List(12)..setAll(0, List.generate(12, (_) => _rng.nextInt(256)));
    final box = await _algo.encrypt(plain, secretKey: key, nonce: nonce);

    final header = utf8.encode(_kHeaderCurrent);
    final out = BytesBuilder();
    out.add(header);
    out.add(nonce);
    out.add(box.cipherText);
    out.add(box.mac.bytes);
    return out.takeBytes();
  }

  // Solo para uso interno desde readDecryptedFile (necesita saber header y file)
  Future<Uint8List> _decryptWithHeader(String header, Uint8List data) async {
    final nonce = data.sublist(3, 15);
    final mac = Mac(data.sublist(data.length - 16));
    final cipher = data.sublist(15, data.length - 16);

    SecretKey? key;
    if (header == _kHeaderCurrent) {
      key = await _getOrCreateKey(_kKeyV2);
    } else if (header == _kHeaderOld) {
      key = await _tryGetKey(_kKeyV1);
      key ??= await _getOrCreateKey(_kKeyV1); // por si es 1er uso
    } else {
      throw const FormatException('Formato no reconocido');
    }

    final box = SecretBox(cipher, nonce: nonce, mac: mac);
    final clear = await _algo.decrypt(box, secretKey: key); // List<int>
    return Uint8List.fromList(clear);
  }

  Future<void> writeEncryptedFile(File file, Uint8List plain) async {
    try {
      final enc = await encrypt(plain);
      await _atomicWrite(file, enc);
    } catch (e, st) {
      await ErrorReport.I.recordError(e, st, hint: 'writeEncryptedFile');
      rethrow;
    }
  }

  // Lee, decide versiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n, descifra, y MIGRA a GN2 si venÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­a en GN1
  Future<Uint8List?> readDecryptedFile(File file) async {
    if (!await file.exists()) return null;
    try {
      final enc = await file.readAsBytes();
      if (enc.length < 3 + 12 + 16) {
        throw const FormatException('Archivo muy corto');
      }
      final header = utf8.decode(enc.sublist(0, 3));
      final plain = await _decryptWithHeader(header, enc);

      // migraciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n: si era GN1 -> reescribir como GN2
      if (header != _kHeaderCurrent) {
        try {
          await writeEncryptedFile(file, plain);
        } catch (e, st) {
          // no bloquea lectura si falla re-escritura
          await ErrorReport.I.recordError(e, st, hint: 're-encrypt(GN1ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢GN2)');
        }
      }
      return plain;
    } on FormatException catch (e, st) {
      await ErrorReport.I
          .recordError(e, st, hint: 'decrypt FormatException', extra: {
        'path': file.path,
      });
      return null;
    } on Exception catch (e, st) {
      await ErrorReport.I
          .recordError(e, st, hint: 'decrypt Exception', extra: {
        'path': file.path,
      });
      return null;
    }
  }

  Future<void> _atomicWrite(File dst, Uint8List bytes) async {
    final dir = Directory(p.dirname(dst.path));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final tmp = File('${dst.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    if (await dst.exists()) {
      await dst.delete();
    }
    await tmp.rename(dst.path);
  }
}
