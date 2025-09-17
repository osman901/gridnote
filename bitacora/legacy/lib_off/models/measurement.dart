// lib/models/measurement.dart
import 'package:intl/intl.dart';

class Measurement {
  final int? id;
  final String progresiva;
  final double? ohm1m;
  final double? ohm3m;
  final String observations;
  final DateTime? date;
  final double? latitude;
  final double? longitude;
  /// Rutas de fotos asociadas
  final List<String> photos;

  const Measurement({
    this.id,
    this.progresiva = '',
    this.ohm1m,
    this.ohm3m,
    this.observations = '',
    this.date,
    this.latitude,
    this.longitude,
    this.photos = const <String>[],
  });

  /// Instancia vacÃƒÆ’Ã‚Â­a inmutable
  static final Measurement empty = Measurement(
    progresiva: '',
    observations: '',
    photos: <String>[],
  );

  /// Formato corto de fecha para UI
  String get dateString {
    final d = date;
    if (d == null) return '-';
    return DateFormat('dd/MM/yyyy').format(d.toLocal());
  }

  Measurement copyWith({
    int? id,
    String? progresiva,
    double? ohm1m,
    double? ohm3m,
    String? observations,
    DateTime? date,
    double? latitude,
    double? longitude,
    List<String>? photos,
  }) {
    return Measurement(
      id: id ?? this.id,
      progresiva: progresiva ?? this.progresiva,
      ohm1m: ohm1m ?? this.ohm1m,
      ohm3m: ohm3m ?? this.ohm3m,
      observations: observations ?? this.observations,
      date: date ?? this.date,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      photos: photos ?? this.photos,
    );
  }

  // ---------- Igualdad por valor ----------
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Measurement &&
        other.id == id &&
        other.progresiva == progresiva &&
        other.ohm1m == ohm1m &&
        other.ohm3m == ohm3m &&
        other.observations == observations &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.date == date &&
        _listEquals(other.photos, photos);
  }

  @override
  int get hashCode => Object.hash(
    id,
    progresiva,
    ohm1m,
    ohm3m,
    observations,
    latitude,
    longitude,
    date,
    Object.hashAll(photos),
  );

  static bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ---------- JSON ----------
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'progresiva': progresiva,
    'ohm1m': ohm1m,
    'ohm3m': ohm3m,
    'observations': observations,
    'date': date?.toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'photos': photos,
  };

  factory Measurement.fromJson(Map<String, dynamic> j) {
    final rawPhotos = j['photos'];
    final List<String> ph = rawPhotos is List
        ? rawPhotos
        .map((e) => e?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList()
        : const <String>[];

    return Measurement(
      id: j['id'] as int?,
      progresiva: (j['progresiva'] ?? '').toString(),
      ohm1m: (j['ohm1m'] as num?)?.toDouble(),
      ohm3m: (j['ohm3m'] as num?)?.toDouble(),
      observations: (j['observations'] ?? '').toString(),
      date: DateTime.tryParse((j['date'] ?? '').toString()),
      latitude: (j['latitude'] as num?)?.toDouble(),
      longitude: (j['longitude'] as num?)?.toDouble(),
      photos: ph,
    );
  }
}
