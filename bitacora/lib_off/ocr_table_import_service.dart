// lib/services/ocr_table_import_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show compute;
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/measurement.dart';

/// Importa una "tabla" desde una foto con bajo uso de RAM.
/// - Redimensiona la imagen antes del OCR.
/// - Reutiliza el recognizer (evita picos al cargar/descargar el modelo nativo).
class OcrTableImportService {
  final ImagePicker _picker = ImagePicker();

  // Reutilizamos una sola instancia durante toda la vida del proceso.
  static final TextRecognizer _recognizer =
  TextRecognizer(script: TextRecognitionScript.latin);

  /// Toma una foto y devuelve una lista de Measurement parseados del texto.
  Future<List<Measurement>> fromCamera() async {
    final XFile? x = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      maxWidth: 1600, // mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡s bajo = menos RAM
      maxHeight: 1600,
      imageQuality: 75,
      requestFullMetadata: false,
    );
    if (x == null) return <Measurement>[];
    return _processPath(x.path);
  }

  /// Selecciona desde galerÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­a y devuelve Measurements parseados del texto.
  Future<List<Measurement>> fromGallery() async {
    final XFile? x = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 75,
      requestFullMetadata: false,
    );
    if (x == null) return <Measurement>[];
    return _processPath(x.path);
  }

  Future<List<Measurement>> _processPath(String path) async {
    final InputImage input = InputImage.fromFilePath(path);
    final RecognizedText result = await _recognizer.processImage(input);
    return compute(_parseTextToMeasurements, result.text);
  }

  /// Cierra manualmente el recognizer si querÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©s liberar memoria.
  static Future<void> disposeRecognizer() async => _recognizer.close();
}

/// Parser en isolate. Convierte texto plano a filas Measurement.
List<Measurement> _parseTextToMeasurements(String fullText) {
  final List<String> lines = fullText
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  // Filtra encabezados comunes
  final List<String> dataLines = lines.where((l) {
    final low = l.toLowerCase();
    return !(low.contains('progresiva') || low.contains('1m') || low.contains('3m'));
  }).toList();

  final List<Measurement> out = <Measurement>[];

  bool _isDouble(String s) => double.tryParse(s.replaceAll(',', '.')) != null;
  double _toDouble(String s) => double.parse(s.replaceAll(',', '.'));

  bool _isLat(String s) {
    final d = double.tryParse(s.replaceAll(',', '.'));
    return d != null && d >= -90 && d <= 90;
  }

  bool _isLng(String s) {
    final d = double.tryParse(s.replaceAll(',', '.'));
    return d != null && d >= -180 && d <= 180;
  }

  DateTime? _tryDate(String s) {
    final a = RegExp(r'^(\d{2})[\/\-\.](\d{2})[\/\-\.](\d{4})$'); // dd/mm/yyyy
    final b = RegExp(r'^(\d{4})[\/\-\.](\d{2})[\/\-\.](\d{2})$'); // yyyy-mm-dd
    if (a.hasMatch(s)) {
      final m = a.firstMatch(s)!;
      return DateTime.tryParse('${m.group(3)}-${m.group(2)}-${m.group(1)}');
    }
    if (b.hasMatch(s)) {
      final m = b.firstMatch(s)!;
      return DateTime.tryParse('${m.group(1)}-${m.group(2)}-${m.group(3)}');
    }
    return null;
  }

  for (final raw in dataLines) {
    final parts = raw
        .split(RegExp(r'[;\t]+|\s{2,}'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    String progresiva = '';
    double? ohm1m;
    double? ohm3m;
    String obs = '';
    DateTime? date;
    double? lat;
    double? lng;

    for (final p in parts) {
      if (progresiva.isEmpty && !_isDouble(p) && _tryDate(p) == null) {
        progresiva = p;
        continue;
      }
      final d = _tryDate(p);
      if (d != null) {
        date = d;
        continue;
      }
      if (lat == null && _isLat(p)) {
        lat = _toDouble(p);
        continue;
      }
      if (lng == null && _isLng(p)) {
        lng = _toDouble(p);
        continue;
      }
      if (_isDouble(p)) {
        if (ohm1m == null) {
          ohm1m = _toDouble(p);
        } else if (ohm3m == null) {
          ohm3m = _toDouble(p);
        } else {
          obs = obs.isEmpty ? p : '$obs $p';
        }
      } else {
        obs = obs.isEmpty ? p : '$obs $p';
      }
    }

    // AjustÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ aquÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­ si tu Measurement requiere no-nulos.
    out.add(Measurement(
      progresiva: progresiva,
      ohm1m: ohm1m,
      ohm3m: ohm3m,
      observations: obs,
      date: date,
      latitude: lat,
      longitude: lng,
    ));
  }
  return out;
}
