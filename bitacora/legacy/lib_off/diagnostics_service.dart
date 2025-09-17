// lib/services/diagnostics_service.dart
import 'package:hive/hive.dart';

class DiagnosticsService {
  DiagnosticsService._();
  static final DiagnosticsService instance = DiagnosticsService._();

  Box<List>? _box;
  Future<void> _ensure() async {
    _box ??= await Hive.openBox<List>('diagnostics_logs');
  }

  Future<void> log(String tag, String message) async {
    await _ensure();
    final now = DateTime.now().toIso8601String();
    final entry = '[$now][$tag] $message';
    final list = List<String>.from((_box!.get('logs') ?? const <String>[]));
    list.add(entry);
    await _box!.put('logs', list);
  }

  Future<List<String>> dump() async {
    await _ensure();
    return List<String>.from((_box!.get('logs') ?? const <String>[]));
  }

  Future<void> clear() async {
    await _ensure();
    await _box!.put('logs', <String>[]);
  }
}
