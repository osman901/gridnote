// lib/services/attachments_service.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';
import 'package:url_launcher/url_launcher.dart';

import 'location_service.dart';

/// Servicio de adjuntos: cámara/galería/ubicación/firma + abrir mapas.
class AttachmentsService {
  AttachmentsService._();
  static final AttachmentsService instance = AttachmentsService._();

  final ImagePicker _picker = ImagePicker();

  /// Abre la cámara y devuelve la ruta del archivo (o null si se cancela).
  Future<String?> pickFromCamera() async {
    final x =
    await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    return x?.path;
  }

  /// Abre la galería y devuelve la ruta del archivo (o null si se cancela).
  Future<String?> pickFromGallery() async {
    final x =
    await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    return x?.path;
  }

  /// Captura rápida ultra-precisa (sin internet). Devuelve 'geo:<lat>,<lng>'.
  Future<String?> getUltraPreciseLocation() async {
    try {
      final fix = await LocationService.instance.captureExact(
        warmup: const Duration(seconds: 5),
        timeout: const Duration(seconds: 15),
        targetAccuracyMeters: 20,
      );
      if (fix == null) return null;
      return 'geo:${fix.latitude},${fix.longitude}';
    } catch (_) {
      // Fallback a lectura rápida
      try {
        final p = await LocationService.instance.getCurrent();
        return 'geo:${p.latitude},${p.longitude}';
      } catch (_) {
        return null;
      }
    }
  }

  /// Compat: usa la versión ultra-precisa.
  Future<String?> getCurrentLocation() => getUltraPreciseLocation();

  /// Diálogo de firma. Devuelve PNG temporal o null.
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
    final file =
    File('${dir.path}/signature_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(png, flush: true);
    return file.path;
  }

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
}
