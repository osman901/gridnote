import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PhotoStore {
  PhotoStore._();
  static final ImagePicker _picker = ImagePicker();

  static Future<Directory> _rowDir(String sheetId, Object rowId) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'photos', sheetId, rowId.toString()));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<File?> addFromCamera(String sheetId, Object rowId) async {
    XFile? x;
    try {
      x = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2048,
        imageQuality: 92,
      );

      // Android puede matar la app: intentar recuperar.
      if (x == null && Platform.isAndroid) {
        final lost = await _picker.retrieveLostData();
        if (!lost.isEmpty && lost.file != null) {
          x = lost.file;
        }
      }
    } catch (_) {}
    if (x == null) return null;

    final dir = await _rowDir(sheetId, rowId);
    final ts = DateTime.now().toUtc().millisecondsSinceEpoch;
    final target = File(p.join(dir.path, 'IMG_$ts.jpg'));

    try {
      await x.saveTo(target.path); // preferido (sin copia doble)
    } catch (_) {
      await File(x.path).copy(target.path); // fallback
    }
    return await target.exists() ? target : null;
  }

  static Future<List<File>> list(String sheetId, Object rowId) async {
    final dir = await _rowDir(sheetId, rowId);
    if (!await dir.exists()) return <File>[];
    final files = await dir
        .list()
        .where((e) => e is File && e.path.toLowerCase().endsWith('.jpg'))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return files;
  }

  /// Nuevo: borrar una foto concreta.
  static Future<void> delete(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}
