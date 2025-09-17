// lib/services/notes_service.dart
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Servicio simple para notas en TEXTO PLANO (por sheetId) usando Hive.
/// - Guarda como String
/// - Intenta leer formatos viejos (JSON) y extraer "text" si existe.
class NotesService {
  NotesService._();
  static final instance = NotesService._();

  static const String _boxName = 'notes_box';

  Future<Box> _openBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  /// Carga la nota asociada a [sheetId] como String.
  Future<String> loadText(String sheetId) async {
    final box = await _openBox();
    final key = 'note_$sheetId';
    final raw = box.get(key);

    if (raw is String) {
      // Si es JSON con {"text": "..."} lo devolvemos; si no, es texto plano.
      try {
        final obj = jsonDecode(raw);
        if (obj is Map && obj['text'] is String) return obj['text'] as String;
      } catch (_) {/* no era JSON, devolvemos tal cual */}
      return raw;
    }
    return '';
  }

  /// Guarda [text] como String.
  Future<void> saveText(String sheetId, String text) async {
    final box = await _openBox();
    final key = 'note_$sheetId';
    await box.put(key, text);
  }

  /// Borra la nota.
  Future<void> clear(String sheetId) async {
    final box = await _openBox();
    await box.delete('note_$sheetId');
  }
}
