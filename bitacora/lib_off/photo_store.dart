// lib/services/photo_store.dart
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// PhotoStore con cÃƒÆ’Ã‚Â¡mara IN-APP (`camera`) y fallback a `image_picker`.
/// Guarda fotos en: /photos/<sheetId>/<rowId>/IMG_<epoch>.jpg
class PhotoStore {
  PhotoStore._();

  static final bool _highEndDevice =
      Platform.numberOfProcessors >= 8 || (Platform.isIOS && Platform.numberOfProcessors >= 6);
  static final double _maxDim = _highEndDevice ? 1920.0 : 1280.0;
  static final int _quality = _highEndDevice ? 90 : 72;

  static bool _busy = false;

  static Future<Directory> _rowDir(String sheetId, Object rowId) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'photos', sheetId, rowId.toString()));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Lista fotos recientes globales guardadas por PhotoStore. MÃƒÆ’Ã‚Â¡s nuevas primero.
  static Future<List<String>> listRecent({int limit = 120}) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'photos'));
    if (!await dir.exists()) return <String>[];

    final files = await dir
        .list(recursive: true, followLinks: false)
        .where((e) => e is File && e.path.toLowerCase().endsWith('.jpg'))
        .cast<File>()
        .toList();

    files.sort((a, b) {
      final ta = a.statSync().modified;
      final tb = b.statSync().modified;
      return tb.compareTo(ta);
    });

    return files.take(limit).map((f) => f.path).toList();
  }

  /// CÃƒÆ’Ã‚Â¡mara IN-APP -> guarda en /photos/<sheetId>/<rowId>/IMG_<epoch>.jpg
  static Future<File?> takePhoto(String sheetId, Object rowId) async {
    if (_busy) return null;
    _busy = true;
    CameraController? controller;
    try {
      final dir = await _rowDir(sheetId, rowId);
      final filepath = p.join(dir.path, 'IMG_${DateTime.now().millisecondsSinceEpoch}.jpg');

      final cameras = await availableCameras();
      if (cameras.isEmpty) return null;
      final camera = cameras.first;

      controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();

      final XFile shot = await controller.takePicture();
      await shot.saveTo(filepath);

      return File(filepath);
    } catch (_) {
      return null;
    } finally {
      try {
        await controller?.dispose();
      } catch (_) {}
      _busy = false;
    }
  }

  /// Seleccionar foto usando la cÃƒÆ’Ã‚Â¡mara del dispositivo (image_picker)
  static Future<File?> addFromCamera(String sheetId, Object entryId) async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      requestFullMetadata: false,
      maxWidth: _maxDim,
      maxHeight: _maxDim,
      imageQuality: _quality,
    );
    if (x == null) return null;

    final file = File(x.path);
    final dir = await _rowDir(sheetId, entryId);
    final destPath = p.join(dir.path, p.basename(file.path));
    return file.copy(destPath);
  }

  /// Seleccionar foto desde galerÃƒÆ’Ã‚Â­a (image_picker)
  static Future<File?> addFromGallery(String sheetId, Object entryId) async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
      maxWidth: _maxDim,
      maxHeight: _maxDim,
      imageQuality: _quality,
    );
    if (x == null) return null;

    final file = File(x.path);
    final dir = await _rowDir(sheetId, entryId);
    final destPath = p.join(dir.path, p.basename(file.path));
    return file.copy(destPath);
  }
}
