// lib/screens/qr_verify_screen.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QrVerifyScreen extends StatefulWidget {
  const QrVerifyScreen({super.key});

  @override
  State<QrVerifyScreen> createState() => _QrVerifyScreenState();
}

class _QrVerifyScreenState extends State<QrVerifyScreen> {
  final MobileScannerController _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _processing = false;
  bool _isScanning = true;

  Map<String, dynamic>? _lastPayload;
  String? _status;   // "valido" | "invalido" | "error"
  String? _message;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  // ───────────── Verificación ─────────────

  Future<void> _onDetect(BarcodeCapture cap) async {
    if (_processing || !_isScanning) return;
    final raw = cap.barcodes.isNotEmpty ? cap.barcodes.first.rawValue : null;
    if (raw == null || raw.isEmpty) return;

    setState(() => _processing = true);

    try {
      final result = await _verifyRaw(raw);
      if (!mounted) return;
      setState(() {
        _status = result.$1;
        _message = result.$2;
        _lastPayload = result.$3;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'error';
        _message = 'Error: $e';
        _lastPayload = null;
      });
    } finally {
      if (!mounted) return;
      setState(() => _processing = false);
      // detener escaneo para evitar detecciones repetidas
      _scanner.stop();
      _isScanning = false;
    }
  }

  // Retorna (status, mensaje, payload)
  Future<(String, String, Map<String, dynamic>?)> _verifyRaw(String raw) async {
    // 1) JSON válido
    Map<String, dynamic> obj;
    try {
      obj = json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      return ('invalido', 'El QR no contiene JSON válido.', null);
    }

    // 2) Firma presente
    final sigB64 = (obj['sig'] ?? obj['signature'])?.toString() ?? '';
    if (sigB64.isEmpty) {
      return ('invalido', 'El QR no trae firma (sig).', obj);
    }
    // Remover la firma del payload canónico
    obj.remove('sig');
    obj.remove('signature');

    // 3) Campos obligatorios (diferenciar ausente vs vacío)
    const requiredKeys = ['p', 'r1', 'r3', 'obs', 'lat', 'lon', 'dt'];
    for (final k in requiredKeys) {
      if (!obj.containsKey(k)) {
        return ('invalido', 'El QR no contiene el campo requerido "$k".', obj);
      }
    }

    // 4) Construcción canónica estricta (todas las claves deben existir)
    final canonical =
        '${obj['p']}|${obj['r1']}|${obj['r3']}|${obj['obs']}|'
        '${obj['lat']}|${obj['lon']}|${obj['dt']}';

    // 5) Cargar secreto (sin fallback hardcodeado)
    final secret = await _loadSecret();
    if (secret == null || secret.isEmpty) {
      return (
      'error',
      'Error de configuración: no hay secreto definido para verificar firmas.',
      obj
      );
    }

    // 6) HMAC esperado
    final expected = _hmacSha256(
      utf8.encode(canonical),
      utf8.encode(secret),
    );

    // 7) Decodificar firma recibida con tolerancia a URL-safe/padding
    final sigBytes = _tryDecodeB64(sigB64);
    if (sigBytes == null) {
      return ('invalido', 'Firma (Base64) inválida.', obj);
    }

    final ok = _ctEquals(expected, sigBytes);
    return (ok ? 'valido' : 'invalido', ok ? 'Firma válida' : 'Firma inválida', obj);
  }

  Future<String?> _loadSecret() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('qr_secret'); // null si no existe
  }

  // HMAC-SHA256
  Uint8List _hmacSha256(List<int> data, List<int> key) {
    final h = Hmac(sha256, key);
    final digest = h.convert(data);
    return Uint8List.fromList(digest.bytes);
  }

  // Base64 url-safe -> estándar con padding (robusto)
  Uint8List? _tryDecodeB64(String s) {
    try {
      var out = s.trim().replaceAll('-', '+').replaceAll('_', '/');
      while (out.length % 4 != 0) {
        out += '=';
      }
      return Uint8List.fromList(base64.decode(out));
    } catch (_) {
      return null;
    }
  }

  /// Comparación en tiempo constante.
  bool _ctEquals(List<int> a, List<int> b) {
    var diff = a.length ^ b.length;
    final len = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < len; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  // ───────────── UI ─────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color barColor = switch (_status) {
      'valido' => Colors.green,
      'invalido' => Colors.red,
      'error' => Colors.orange,
      _ => isDark ? Colors.white24 : Colors.black54,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificar QR'),
        actions: [
          IconButton(
            tooltip: 'Linterna',
            icon: const Icon(Icons.flashlight_on),
            onPressed: () => _scanner.toggleTorch(),
          ),
          IconButton(
            tooltip: 'Cámara frontal/trasera',
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _scanner.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scanner,
            onDetect: _onDetect,
          ),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              color: barColor.withOpacity(0.85),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _status == null ? 'Apuntá a un QR de Gridnote' : _status!.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  if (_message != null)
                    Text(_message!, style: const TextStyle(color: Colors.white)),
                  if (_lastPayload != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _lastPayload.toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_processing)
            const Center(
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Colors.black54,
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: !_isScanning
          ? FloatingActionButton.extended(
        onPressed: () {
          setState(() {
            _status = null;
            _message = null;
            _lastPayload = null;
            _processing = false;
          });
          _scanner.start();
          _isScanning = true;
        },
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Escanear de nuevo'),
      )
          : null,
    );
  }
}
