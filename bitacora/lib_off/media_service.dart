// lib/services/media_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class MediaService {
  MediaService._();
  static final MediaService instance = MediaService._();
  final _picker = ImagePicker();

  Future<({String path, String thumbPath, int size, String hash})?> takePhoto() async {
    final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 95);
    if (x == null) return null;

    final dir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(dir.path, 'photos'))..createSync(recursive: true);
    final thumbsDir = Directory(p.join(dir.path, 'thumbs'))..createSync(recursive: true);

    final bytes = await x.readAsBytes();
    final hash = md5.convert(bytes).toString();

    final fileName = '${DateTime.now().millisecondsSinceEpoch}_$hash.jpg';
    final dst = File(p.join(photosDir.path, fileName))..writeAsBytesSync(bytes);

    // thumb
    final decoded = img.decodeImage(bytes)!;
    final thumb = img.copyResize(decoded, width: 480);
    final thumbBytes = Uint8List.fromList(img.encodeJpg(thumb, quality: 85));
    final thumbPath = p.join(thumbsDir.path, fileName);
    File(thumbPath).writeAsBytesSync(thumbBytes);

    return (path: dst.path, thumbPath: thumbPath, size: bytes.length, hash: hash);
  }
}
