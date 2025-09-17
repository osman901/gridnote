// lib/services/attachments_helper.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';
import 'package:url_launcher/url_launcher.dart';

class AttachmentsHelper {
  AttachmentsHelper._();
  static final AttachmentsHelper instance = AttachmentsHelper._();

  final ImagePicker _picker = ImagePicker();

  Future<String?> pickFromCamera({int imageQuality = 85}) async {
    final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: imageQuality);
    return x?.path;
  }

  Future<String?> pickFromGallery({int imageQuality = 85}) async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: imageQuality);
    return x?.path;
  }

  Future<String?> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;

    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      return 'geo:${pos.latitude.toStringAsFixed(6)},${pos.longitude.toStringAsFixed(6)}';
    } catch (_) {
      return null;
    }
  }

  Future<String?> addSignature(BuildContext context) async {
    final controller = SignatureController(
      penStrokeWidth: 3, penColor: Colors.black, exportBackgroundColor: Colors.white,
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
    final file = File('${dir.path}/firma_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(png, flush: true);
    return file.path;
  }

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

  Future<Directory> _dirForKey(dynamic key) async {
    final base = await getApplicationDocumentsDirectory();
    final safe = (key ?? 'default').toString().replaceAll(RegExp(r'[^\w\-]+'), '_');
    final dir = Directory(p.join(base.path, 'attachments', safe));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> copyToKeyDir(String sourcePath, dynamic key) async {
    final src = File(sourcePath);
    final dir = await _dirForKey(key);
    final name = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(sourcePath)}';
    final dst = File(p.join(dir.path, name));
    await dst.writeAsBytes(await src.readAsBytes(), flush: true);
    return dst.path;
  }
}
