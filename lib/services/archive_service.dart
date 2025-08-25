import 'package:shared_preferences/shared_preferences.dart';

/// Guarda un set de claves archivadas (por ejemplo: `${id}|${progresiva}|${epoch}`).
class ArchiveService {
  ArchiveService._();
  static final ArchiveService instance = ArchiveService._();

  static const _kKey = 'gridnote_archived_v1';

  Future<Set<String>> load() async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_kKey) ?? const <String>[];
    return list.toSet();
  }

  Future<void> toggle(String key, {required bool value}) async {
    final p = await SharedPreferences.getInstance();
    final set = (p.getStringList(_kKey) ?? const <String>[]).toSet();
    if (value) {
      set.add(key);
    } else {
      set.remove(key);
    }
    await p.setStringList(_kKey, set.toList());
  }
}
