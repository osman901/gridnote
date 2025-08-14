import '../models/measurement.dart';

/// Simula una API de paginación ───────────────
class MiServicio {
  /// Devuelve la “siguiente página”. Rellena con tu lógica real.
  static Future<List<Measurement>> fetchNextBatch() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return <Measurement>[];   // ← próximos registros
  }
}