// lib/services/photo_service.dart
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/photo_attachment.dart';
import 'photo_store.dart';

class PhotoService {
  PhotoService._();
  static final PhotoService instance = PhotoService._();
  final ImagePicker _picker = ImagePicker();

  Future<Directory> _sheetDir(String sheetId) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'photos', sheetId));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Lista TODAS las fotos de la planilla (todas las filas y bucket _sheet).
  Future<List<PhotoAttachment>> list(String sheetId) async {
    final root = await _sheetDir(sheetId);
    if (!await root.exists()) return const <PhotoAttachment>[];

    final files = <File>[];
    await for (final ent in root.list(recursive: true, followLinks: false)) {
      if (ent is File && ent.path.toLowerCase().endsWith('.jpg')) {
        files.add(ent);
      }
    }
    files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

    return files.map((f) {
      final created = f.statSync().modified;
      // NO pasamos rowId porque el modelo no lo define.
      // (La UI lo deriva del path si lo necesita.)
      return PhotoAttachment(path: f.path, createdAt: created);
    }).toList();
  }

  /// Saca foto con cámara y la guarda en bucket general "_sheet".
  Future<File?> addFromCamera(String sheetId) =>
      PhotoStore.addFromCamera(sheetId, '_sheet');

  /// Elige de galería y copia a bucket general "_sheet".
  Future<File?> addFromGallery(String sheetId) async {
    XFile? x;
    try {
      x = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 4096,
        imageQuality: 95,
      );
    } catch (_) {}
    if (x == null) return null;

    final dir = Directory(p.join((await _sheetDir(sheetId)).path, '_sheet'));
    if (!await dir.exists()) await dir.create(recursive: true);

    final ts = DateTime.now().toUtc().millisecondsSinceEpoch;
    final target = File(p.join(dir.path, 'IMG_$ts.jpg'));

    try {
      await x.saveTo(target.path);
    } catch (_) {
      await File(x.path).copy(target.path);
    }
    return await target.exists() ? target : null;
  }

  Future<void> delete(PhotoAttachment a) async {
    final f = File(a.path);
    if (await f.exists()) {
      await f.delete();
    }
  }
}
