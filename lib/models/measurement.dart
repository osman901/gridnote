// lib/models/measurement.dart
import 'package:hive/hive.dart';

part 'measurement.g.dart';

@HiveType(typeId: 1)
class Measurement {
  /// Nota: No uses este `id` como clave de Hive. Hive gestiona su propia key
  /// (autoincremental o string). Este `id` es para integraciones externas.
  @HiveField(0) int? id;
  @HiveField(1) String progresiva;
  @HiveField(2) double ohm1m;
  @HiveField(3) double ohm3m;
  @HiveField(4) String observations;
  @HiveField(5) double? latitude;
  @HiveField(6) double? longitude;
  /// Guardar SIEMPRE en UTC para consistencia.
  @HiveField(7) DateTime date;

  Measurement({
    this.id,
    required this.progresiva,
    required this.ohm1m,
    required this.ohm3m,
    required this.observations,
    this.latitude,
    this.longitude,
    required this.date,
  });

  /// Fábrica vacía usando UTC.
  factory Measurement.empty() => Measurement(
    progresiva: '',
    ohm1m: 0,
    ohm3m: 0,
    observations: '',
    date: DateTime.now().toUtc(),
  );

  /// Fecha formateada en zona local del dispositivo.
  String get dateString {
    final d = date.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Measurement copyWith({
    int? id,
    String? progresiva,
    double? ohm1m,
    double? ohm3m,
    String? observations,
    double? latitude,
    double? longitude,
    DateTime? date,
  }) =>
      Measurement(
        id: id ?? this.id,
        progresiva: progresiva ?? this.progresiva,
        ohm1m: ohm1m ?? this.ohm1m,
        ohm3m: ohm3m ?? this.ohm3m,
        observations: observations ?? this.observations,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        date: date ?? this.date,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'progresiva': progresiva,
    'ohm1m': ohm1m,
    'ohm3m': ohm3m,
    'observations': observations,
    'latitude': latitude,
    'longitude': longitude,
    // Guardamos epoch en ms de la versión UTC
    'date': date.toUtc().millisecondsSinceEpoch,
  };

  /// fromJson ESTRICTO: si falta un campo requerido, lanza FormatException.
  factory Measurement.fromJson(Map<String, dynamic> json) {
    // Requeridos
    final prog = _requireString(json, 'progresiva');
    final v1m = _requireDouble(json, 'ohm1m');
    final v3m = _requireDouble(json, 'ohm3m');
    final obs = _requireString(json, 'observations');
    final epochMs = _requireEpochMs(json, 'date');

    return Measurement(
      id: _asIntOrNull(json['id']),
      progresiva: prog,
      ohm1m: v1m,
      ohm3m: v3m,
      observations: obs,
      latitude: _asDoubleOrNull(json['latitude']),
      longitude: _asDoubleOrNull(json['longitude']),
      // Interpretamos el epoch como UTC
      date: DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true),
    );
  }

  // ---------- Helpers de parseo/validación ----------

  static String _requireString(Map<String, dynamic> json, String key) {
    final v = json[key];
    if (v is String) return v;
    if (v != null) return v.toString();
    throw const FormatException(
        'JSON inválido: falta un string requerido.');
  }

  static double _requireDouble(Map<String, dynamic> json, String key) {
    final v = json[key];
    final d = _asDoubleOrNull(v);
    if (d == null) {
      throw const FormatException(
          'JSON inválido: falta o no es numérico un campo double requerido.');
    }
    return d;
  }

  static int _requireEpochMs(Map<String, dynamic> json, String key) {
    final v = json[key];
    final i = _asIntOrNull(v);
    if (i == null) {
      throw const FormatException(
          'JSON inválido: falta o no es entero epoch ms requerido.');
    }
    return i;
  }

  static double? _asDoubleOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      final s = v.trim().replaceAll(',', '.');
      final n = num.tryParse(s);
      return n?.toDouble();
    }
    return null;
  }

  static int? _asIntOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }
}
