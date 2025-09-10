import 'dart:io';
import 'package:path_provider/path_provider.dart';

class NoteService {
  static Future<String> saveNote(String title, String content) async {
    final directory = await getExternalStorageDirectory();
    final path = "${directory!.path}/$title.txt";
    final file = File(path);
    await file.writeAsString(content);
    return path;
  }
}
