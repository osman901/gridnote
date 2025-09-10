import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';
import 'package:url_launcher/url_launcher.dart';

import 'location_service.dart'; // ultra precisa

/// Servicio de adjuntos: cámara/galería/ubicación/firma + utilidades de archivos.
class AttachmentsService {
  AttachmentsService._();
  static final AttachmentsService instance = AttachmentsService._();

  final ImagePicker _picker = ImagePicker();

  // -------------------- Cámara / Galería --------------------

  /// Abre la cámara y devuelve la ruta del archivo (o null si se cancela).
  Future<String?> pickFromCamera({int imageQuality = 85}) async {
    final x = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: imageQuality,
    );
    return x?.path;
  }

  /// Abre la galería y devuelve la ruta del archivo (o null si se cancela).
  Future<String?> pickFromGallery({int imageQuality = 85}) async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: imageQuality,
    );
    return x?.path;
  }

  /// Toma una foto y la copia al directorio de adjuntos de [measurementKey].
  Future<String?> pickFromCameraForKey(dynamic measurementKey) async {
    final src = await pickFromCamera();
    if (src == null || src.isEmpty) return null;
    return copyToKeyDir(src, measurementKey);
  }

  /// Elige de galería y copia al directorio de adjuntos de [measurementKey].
  Future<String?> pickFromGalleryForKey(dynamic measurementKey) async {
    final src = await pickFromGallery();
    if (src == null || src.isEmpty) return null;
    return copyToKeyDir(src, measurementKey);
  }

  // -------------------- Ubicación --------------------

  /// Rápida: devuelve 'geo:<lat>,<lng>' o null si no hay permiso / cancelado.
  Future<String?> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      return null;
    }

    final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    return 'geo:${pos.latitude.toStringAsFixed(6)},${pos.longitude.toStringAsFixed(6)}';
  }

  /// Ultra precisa (offline): escucha un rato y devuelve el mejor fix. Fallback a rápida.
  Future<String?> getUltraPreciseLocation({
    Duration warmup = const Duration(seconds: 7),
    Duration timeout = const Duration(seconds: 15),
    double targetAccuracyMeters = 25,
  }) async {
    try {
      final fix = await LocationService.instance.captureExact(
        warmup: warmup,
        timeout: timeout,
        targetAccuracyMeters: targetAccuracyMeters,
      );
      if (fix == null) return null;
      final lat = fix.latitude.toStringAsFixed(6);
      final lng = fix.longitude.toStringAsFixed(6);
      return 'geo:$lat,$lng';
    } catch (_) {
      return getCurrentLocation();
    }
  }

  // -------------------- Firma --------------------

  /// Diálogo de firma. Devuelve ruta PNG temporal o null.
  Future<String?> addSignature(BuildContext context) async {
    final controller = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    final Uint8List? png = await showDialog<Uint8List?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Firma'),
        content: SizedBox(
          width: 360,
          height: 220,
          child: DecoratedBox(
            decoration: BoxDecoration(border: Border.all(color: Colors.black12)),
            child: Signature(controller: controller, backgroundColor: Colors.white),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancelar')),
          TextButton(onPressed: () => controller.clear(), child: const Text('Borrar')),
          FilledButton(
            onPressed: () async {
              if (controller.isEmpty) return Navigator.pop(ctx, null);
              final bytes = await controller.toPngBytes();
              Navigator.pop(ctx, bytes);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (png == null) return null;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/signature_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(png, flush: true);
    return file.path;
  }

  // -------------------- Mapas --------------------

  /// Abre la app de mapas con un string 'geo:lat,lng' (fallback a Google Maps web).
  Future<void> openGeo(String geo) async {
    if (!geo.startsWith('geo:')) return;
    final uri = Uri.parse(geo);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    final q = geo.substring(4);
    final web = Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
    await launchUrl(web, mode: LaunchMode.externalApplication);
  }

  // -------------------- Archivos por medición (Gallery) --------------------

  /// Directorio donde guardar/leer adjuntos para una `measurementKey`.
  Future<Directory> dirForKey(dynamic measurementKey) async {
    final base = await getApplicationDocumentsDirectory();
    final safe = _safeKey(measurementKey);
    final dir = Directory(p.join(base.path, 'attachments', safe));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Copia [sourcePath] al directorio de `measurementKey` y devuelve la nueva ruta.
  Future<String> copyToKeyDir(String sourcePath, dynamic measurementKey) async {
    final src = File(sourcePath);
    final dir = await dirForKey(measurementKey);
    final name = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(sourcePath)}';
    final dst = File(p.join(dir.path, name));
    await dst.writeAsBytes(await src.readAsBytes(), flush: true);
    return dst.path;
  }

  String _safeKey(dynamic k) {
    final s = (k ?? 'default').toString();
    return s.replaceAll(RegExp(r'[^\w\-]+'), '_');
  }
}
