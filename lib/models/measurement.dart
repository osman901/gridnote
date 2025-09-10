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
  /// Siempre guardada como **medianoche UTC (fecha-solo)**
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

  /// Normaliza un DateTime local a **medianoche UTC** (fecha-solo).
  static DateTime utcFromLocalDate(DateTime local) =>
      DateTime.utc(local.year, local.month, local.day);

  factory Measurement.empty() => Measurement(
    progresiva: '',
    ohm1m: 0,
    ohm3m: 0,
    observations: '',
    date: utcFromLocalDate(DateTime.now()),
  );

  /// Fecha legible local DD/MM/YYYY (para UI/Excel).
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
      // invariante: siempre medianoche UTC
      date: date != null ? utcFromLocalDate(date.toLocal()) : this.date,
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
    // persistimos epoch en UTC
    'date': date.toUtc().millisecondsSinceEpoch,
  };

  factory Measurement.fromJson(Map<String, dynamic> json) {
    DateTime fromEpoch(int ms) =>
        DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    final epochMs = _requireEpochMs(json, 'date');

    return Measurement(
      id: _asIntOrNull(json['id']),
      progresiva: _requireString(json, 'progresiva'),
      ohm1m: _requireDouble(json, 'ohm1m'),
      ohm3m: _requireDouble(json, 'ohm3m'),
      observations: _requireString(json, 'observations'),
      latitude: _asDoubleOrNull(json['latitude']),
      longitude: _asDoubleOrNull(json['longitude']),
      // si viniera con hora, lo reducimos a fecha-solo
      date: utcFromLocalDate(fromEpoch(epochMs).toLocal()),
    );
  }

  List<String> get validationErrors {
    final e = <String>[];
    if (progresiva.trim().isEmpty) e.add('La progresiva no puede estar vacía.');
    if (ohm1m.isNaN || ohm1m < 0) e.add('El valor de 1 mΩ no puede ser negativo.');
    if (ohm3m.isNaN || ohm3m < 0) e.add('El valor de 3 mΩ no puede ser negativo.');
    final todayUtc = utcFromLocalDate(DateTime.now());
    if (date.isAfter(todayUtc.add(const Duration(days: 1)))) {
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

  // ---------- utils parse ----------
  static String _requireString(Map<String, dynamic> j, String k) {
    final v = j[k]; if (v is String) return v; if (v != null) return v.toString();
    throw const FormatException('JSON inválido: falta string requerido.');
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