import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrResult {
  OcrResult({this.ohm1m, this.ohm3m, this.rawText});
  final double? ohm1m;
  final double? ohm3m;
  final String? rawText;
}

class OcrService {
  OcrService._();
  static final OcrService instance = OcrService._();

  Future<OcrResult> readOhmsFromImage(File file) async {
    final rec = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFile(file);
      final visionText = await rec.processImage(input);
      final text = visionText.text;
      double? v1, v3;

      final lines = text.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      final re1 = RegExp(r'(1m)[^\d\-]*([0-9]+[.,]?[0-9]*)', caseSensitive: false);
      final re3 = RegExp(r'(3m)[^\d\-]*([0-9]+[.,]?[0-9]*)', caseSensitive: false);
      for (final l in lines) {
        final m1 = re1.firstMatch(l);
        if (m1 != null) v1 ??= _toDouble(m1.group(2)!);
        final m3 = re3.firstMatch(l);
        if (m3 != null) v3 ??= _toDouble(m3.group(2)!);
      }

      if (v1 == null || v3 == null) {
        final nums = RegExp(r'(-?\d+(?:[.,]\d+)?)')
            .allMatches(text)
            .map((m) => _toDouble(m.group(0)!))
            .whereType<double>()
            .toList()
          ..sort();
        if (nums.isNotEmpty && v1 == null) v1 = nums.last;
        if (nums.length > 1 && v3 == null) v3 = nums[nums.length - 2];
      }

      return OcrResult(ohm1m: v1, ohm3m: v3, rawText: text);
    } finally {
      await rec.close();
    }
  }

  double? _toDouble(String s) => double.tryParse(s.replaceAll(',', '.'));
}
