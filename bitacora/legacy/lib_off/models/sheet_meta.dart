// lib/models/sheet_meta.dart
class SheetMeta {
  const SheetMeta({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.latitude,
    this.longitude,
    this.author,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double? latitude;
  final double? longitude;
  final String? author;

  // No puede ser const porque DateTime(...) no es const.
  static final SheetMeta empty = SheetMeta(
    id: '',
    name: '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  SheetMeta copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? latitude,
    double? longitude,
    String? author,
  }) {
    return SheetMeta(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      author: author ?? this.author,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'author': author,
  };

  factory SheetMeta.fromJson(Map<String, dynamic> j) {
    DateTime parseDate(dynamic v) {
      if (v is DateTime) return v;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      final s = v?.toString() ?? '';
      return DateTime.tryParse(s) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    return SheetMeta(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      createdAt: parseDate(j['createdAt']),
      updatedAt: parseDate(j['updatedAt']),
      latitude: (j['latitude'] as num?)?.toDouble(),
      longitude: (j['longitude'] as num?)?.toDouble(),
      author: j['author']?.toString(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SheetMeta &&
        other.id == id &&
        other.name == name &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.author == author;
  }

  @override
  int get hashCode => Object.hash(
    id, name, createdAt, updatedAt, latitude, longitude, author,
  );

  @override
  String toString() =>
      'SheetMeta(id: $id, name: $name, createdAt: $createdAt, updatedAt: $updatedAt, lat: $latitude, lng: $longitude, author: $author)';
}
