import 'package:flutter/foundation.dart' show compute;
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/measurement.dart';

/// Importa una "tabla" desde una foto con bajo uso de RAM.
/// - Redimensiona la imagen antes del OCR.
/// - Reutiliza el recognizer (evita picos al cargar/descargar el modelo nativo).
class OcrTableImportService {
  final _picker = ImagePicker();

  // Reutilizamos una sola instancia durante toda la vida del proceso.
  static final TextRecognizer _recognizer =
  TextRecognizer(script: TextRecognitionScript.latin);

  Future<List<Measurement>> fromCamera() async {
    final x = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      maxWidth: 1600,          // más bajo = menos RAM
      maxHeight: 1600,
      imageQuality: 75,
      requestFullMetadata: false,
    );
    if (x == null) return <Measurement>[];
    return _processPath(x.path);
  }

  Future<List<Measurement>> fromGallery() async {
    final x = await _picker.pickImage(
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
    final result = await _recognizer.processImage(InputImage.fromFilePath(path));
    return compute(_parseTextToMeasurements, result.text);
  }

  /// Llamalo si alguna vez querés cerrar manualmente el recognizer (no obligatorio).
  static Future<void> disposeRecognizer() async => _recognizer.close();
}

List<Measurement> _parseTextToMeasurements(String fullText) {
  final lines = fullText
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  final dataLines = lines.where((l) {
    final low = l.toLowerCase();
    return !(low.contains('progresiva') || low.contains('1m') || low.contains('3m'));
  }).toList();

  final out = <Measurement>[];
  for (final raw in dataLines) {
    final parts = raw
        .split(RegExp(r'[;\t]+|\s{2,}'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    String progresiva = '';
    double ohm1m = 0;
    double ohm3m = 0;
    String obs = '';
    DateTime date = DateTime.now();
    double? lat;
    double? lng;

    bool isDouble(String s) => double.tryParse(s.replaceAll(',', '.')) != null;
    double toDouble(String s) => double.parse(s.replaceAll(',', '.'));

    bool isLat(String s) {
      final d = double.tryParse(s.replaceAll(',', '.'));
      return d != null && d >= -90 && d <= 90;
    }

    bool isLng(String s) {
      final d = double.tryParse(s.replaceAll(',', '.'));
      return d != null && d >= -180 && d <= 180;
    }

    DateTime? tryDate(String s) {
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

    for (final p in parts) {
      if (progresiva.isEmpty && !isDouble(p) && tryDate(p) == null) {
        progresiva = p;
        continue;
      }
      final d = tryDate(p);
      if (d != null) {
        date = d;
        continue;
      }
      if (lat == null && isLat(p)) {
        lat = toDouble(p);
        continue;
      }
      if (lng == null && isLng(p)) {
        lng = toDouble(p);
        continue;
      }
      if (isDouble(p)) {
        if (ohm1m == 0) {
          ohm1m = toDouble(p);
        } else if (ohm3m == 0) {
          ohm3m = toDouble(p);
        } else {
          obs = obs.isEmpty ? p : '$obs $p';
        }
      } else {
        obs = obs.isEmpty ? p : '$obs $p';
      }
    }

    out.add(Measurement(
      id: null,
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
