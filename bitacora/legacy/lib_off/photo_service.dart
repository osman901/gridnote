// lib/services/photo_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/photo_attachment.dart';

class PhotoService {
  PhotoService._();
  static final instance = PhotoService._();

  final ImagePicker _picker = ImagePicker();

  // LÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­mite para evitar OOM en equipos de baja memoria.
  static const int maxPhotosPerSheet = 20;

  Future<Directory> _sheetDir(String sheetId) async {
    final List<Directory>? pics =
    await getExternalStorageDirectories(type: StorageDirectory.pictures);
    final Directory base =
    (pics != null && pics.isNotEmpty) ? pics.first : await getApplicationDocumentsDirectory();

    final dir = Directory(p.join(base.path, 'Gridnote', sheetId));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Lista todas las fotos de la planilla, mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡s recientes primero.
  Future<List<PhotoAttachment>> list(String sheetId) async {
    final dir = await _sheetDir(sheetId);
    if (!await dir.exists()) return [];

    final List<PhotoAttachment> out = [];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final ext = p.extension(entity.path).toLowerCase();
      if (ext != '.jpg' && ext != '.jpeg' && ext != '.png' && ext != '.webp') continue;

      final created = File(entity.path).lastModifiedSync();

      // Tu modelo NO tiene rowId, asÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­ que no lo pasamos.
      out.add(PhotoAttachment(
        path: entity.path,
        createdAt: created, // requerido por tu modelo
      ));
    }

    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  Future<File?> addFromCamera(String sheetId, {String? rowId}) async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      requestFullMetadata: false,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null) return null;
    return _saveResized(picked, sheetId, rowId: rowId);
  }

  Future<File?> addFromGallery(String sheetId, {String? rowId}) async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null) return null;
    return _saveResized(picked, sheetId, rowId: rowId);
  }

  /// Elimina el archivo en disco.
  Future<void> delete(PhotoAttachment a) async {
    final f = File(a.path);
    if (await f.exists()) {
      await f.delete();
    }
  }

  Future<File> _saveResized(XFile picked, String sheetId, {String? rowId}) async {
    // LÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­mite por planilla para evitar caÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­das por memoria.
    final existing = await list(sheetId);
    if (existing.length >= maxPhotosPerSheet) {
      throw Exception('Demasiadas fotos: lÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­mite de $maxPhotosPerSheet por planilla');
    }

    final bytes = await picked.readAsBytes(); // Uint8List (viene de foundation)
    final outBytes = await compute(_downscaleJpeg, <String, Object?>{
      'bytes': bytes,
      'target': 1600,
      'quality': 85,
    });

    final baseDir = await _sheetDir(sheetId);
    final bucket = rowId ?? '_sheet';
    final targetDir = Directory(p.join(baseDir.path, bucket));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final name = 'ph_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = File(p.join(targetDir.path, name));
    await file.writeAsBytes(outBytes, flush: true);
    return file;
  }
}

/// FunciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n toplevel para compute(): recibe Map y devuelve Uint8List.
Uint8List _downscaleJpeg(Map<String, Object?> m) {
  final bytes = m['bytes'] as Uint8List;
  final target = m['target'] as int;
  final quality = m['quality'] as int;

  final src = img.decodeImage(bytes);
  if (src == null) return bytes;

  final w = src.width, h = src.height;
  final longEdge = w > h ? w : h;
  if (longEdge > target) {
    final scale = target / longEdge;
    final dst = img.copyResize(
      src,
      width: (w * scale).round(),
      height: (h * scale).round(),
      interpolation: img.Interpolation.average,
    );
    return Uint8List.fromList(img.encodeJpg(dst, quality: quality));
  }
  return Uint8List.fromList(img.encodeJpg(src, quality: quality));
}
