import 'package:hive_flutter/hive_flutter.dart';

class NotesMdService {
  NotesMdService._();
  static final instance = NotesMdService._();

  static const _boxName = 'notes_box';

  Future<Box> _openBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  Future<String> load(String sheetId) async {
    final box = await _openBox();
    return (box.get('note_$sheetId') as String?) ?? '';
  }

  Future<void> save(String sheetId, String text) async {
    final box = await _openBox();
    await box.put('note_$sheetId', text);
  }

  Future<void> clear(String sheetId) async {
    final box = await _openBox();
    await box.delete('note_$sheetId');
  }
}
