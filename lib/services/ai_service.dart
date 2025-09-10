// lib/services/ai_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AiService {
  AiService._();
  static final AiService instance = AiService._();

  GenerativeModel? _model;
  bool _ready = false;
  bool get isReady => _ready;

  Future<void> init() async {
    final key = dotenv.env['GEMINI_API_KEY']?.trim();
    if (key == null || key.isEmpty) {
      debugPrint('[AI] Falta GEMINI_API_KEY en .env');
      _ready = false;
      return;
    }
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: key,
    );
    _ready = true;

    // warm-up silencioso
    try {
      await _model!.generateContent([Content.text('ping')]);
    } catch (_) {}
  }

  Future<String> quickAnswer(String prompt) async {
    if (!_ready || _model == null) return 'IA no configurada';
    try {
      final res = await _model!.generateContent([Content.text(prompt)]);
      return (res.text ?? '').trim().isEmpty ? '(sin respuesta)' : res.text!.trim();
    } catch (e) {
      return 'IA error: $e';
    }
  }

  // ← alias para que el código existente compile sin tocar HomeScreen
  Future<String> ask(String prompt) => quickAnswer(prompt);
}

