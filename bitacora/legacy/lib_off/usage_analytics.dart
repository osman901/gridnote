import 'package:hive/hive.dart';

class UsageAnalytics {
  UsageAnalytics._();
  static final UsageAnalytics instance = UsageAnalytics._();

  Box<int>? _box;

  Future<void> _ensure() async {
    _box ??= await Hive.openBox<int>('usage');
  }

  Future<void> bump(String key) async {
    await _ensure();
    final c = _box!.get(key) ?? 0;
    await _box!.put(key, c + 1);
  }

  Future<Map<String, int>> dump() async {
    await _ensure();
    return Map<String, int>.from(_box!.toMap());
  }
}
