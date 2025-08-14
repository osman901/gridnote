import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class AttachmentService {
  static Future<Directory> dirForKey(dynamic key) async {
    final docs = await getApplicationDocumentsDirectory();
    final d = Directory(p.join(docs.path, 'attachments', '$key'));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static Future<File?> takePhotoToKey(dynamic key) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2000,
      imageQuality: 85,
    );
    if (x == null) return null;
    final dir = await dirForKey(key);
    final name =
        'att_${DateTime.now().millisecondsSinceEpoch}${p.extension(x.path).toLowerCase()}';
    final dest = File(p.join(dir.path, name));
    return File(x.path).copy(dest.path);
  }
}
