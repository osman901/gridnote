// lib/services/usage_analytics.dart
import 'package:hive/hive.dart';

class UsageAnalytics {
  UsageAnalytics._();
  static final UsageAnalytics instance = UsageAnalytics._();

  Box<Map>? _box;

  Future<void> _ensure() async {
    _box ??= await Hive.openBox<Map>('usage_stats');
  }

  Future<void> bump(String key) async {
    await _ensure();
    final m = Map<String, int>.from((_box!.get('counters') ?? {}) as Map? ?? {});
    m[key] = (m[key] ?? 0) + 1;
    await _box!.put('counters', m);
  }

  Future<Map<String, int>> dump() async {
    await _ensure();
    return Map<String, int>.from((_box!.get('counters') ?? {}) as Map? ?? {});
  }
}
