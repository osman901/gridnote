import 'package:hive/hive.dart';

part 'measurement.g.dart';

@HiveType(typeId: 1)
class Measurement {
  static const List<String> defaultHeaders = [
    'Fecha', 'Progresiva', '1m (Ω)', '3m (Ω)', 'Obs', 'Lat', 'Lng'
  ];

  @HiveField(0) final int? id;
  @HiveField(1) final String progresiva;
  @HiveField(2) final double ohm1m;
  @HiveField(3) final double ohm3m;
  @HiveField(4) final String observations;
  @HiveField(5) final double? latitude;
  @HiveField(6) final double? longitude;
  @HiveField(7) final DateTime date;

  const Measurement({
    this.id,
    required this.progresiva,
    required this.ohm1m,
    required this.ohm3m,
    required this.observations,
    this.latitude,
    this.longitude,
    required this.date,
  });

  factory Measurement.empty() => Measurement(
    progresiva: '',
    ohm1m: 0,
    ohm3m: 0,
    observations: '',
    date: DateTime.now().toUtc(),
  );

  /// Devuelve la fecha en formato DD/MM/YYYY local.
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
  }) {
    return Measurement(
      id: id ?? this.id,
      progresiva: progresiva ?? this.progresiva,
      ohm1m: ohm1m ?? this.ohm1m,
      ohm3m: ohm3m ?? this.ohm3m,
      observations: observations ?? this.observations,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      date: date ?? this.date,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'progresiva': progresiva,
    'ohm1m': ohm1m,
    'ohm3m': ohm3m,
    'observations': observations,
    'latitude': latitude,
    'longitude': longitude,
    'date': date.toUtc().millisecondsSinceEpoch,
  };

  factory Measurement.fromJson(Map<String, dynamic> json) {
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
      date: DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true),
    );
  }

  /// Validaciones básicas para mostrar mensajes al usuario.
  List<String> get validationErrors {
    final e = <String>[];
    if (progresiva.trim().isEmpty) e.add('La progresiva no puede estar vacía.');
    if (ohm1m.isNaN || ohm1m < 0) e.add('El valor de 1 mΩ no puede ser negativo.');
    if (ohm3m.isNaN || ohm3m < 0) e.add('El valor de 3 mΩ no puede ser negativo.');
    final nowUtc = DateTime.now().toUtc();
    if (date.isAfter(nowUtc.add(const Duration(hours: 24)))) {
      e.add('La fecha no puede ser futura.');
    }
    return e;
  }

  @override
  bool operator ==(Object o) =>
      o is Measurement &&
          progresiva == o.progresiva &&
          ohm1m == o.ohm1m &&
          ohm3m == o.ohm3m &&
          observations == o.observations &&
          latitude == o.latitude &&
          longitude == o.longitude &&
          date == o.date;

  @override
  int get hashCode => Object.hash(
    progresiva, ohm1m, ohm3m, observations, latitude, longitude, date,
  );

  // Utilidades privadas para parseo seguro.
  static String _requireString(Map<String, dynamic> j, String k) {
    final v = j[k]; if (v is String) return v; if (v != null) return v.toString();
    throw const FormatException('JSON inválido: falta un string requerido.');
  }
  static double _requireDouble(Map<String, dynamic> j, String k) {
    final v = j[k]; final d = _asDoubleOrNull(v);
    if (d == null) throw const FormatException('JSON inválido: falta double requerido.');
    return d;
  }
  static int _requireEpochMs(Map<String, dynamic> j, String k) {
    final v = j[k]; final i = _asIntOrNull(v);
    if (i == null) throw const FormatException('JSON inválido: falta epoch ms requerido.');
    return i;
  }
  static double? _asDoubleOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      final n = num.tryParse(v.trim().replaceAll(',', '.'));
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
