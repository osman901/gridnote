import 'dart:convert';

class SheetMeta {
  final String id;
  String name;
  DateTime createdAt;     // Siempre en UTC
  double? latitude;
  double? longitude;

  SheetMeta({
    required this.id,
    required this.name,
    DateTime? createdAt,
    this.latitude,
    this.longitude,
  }) : createdAt = (createdAt ?? DateTime.now()).toUtc();

  SheetMeta copyWith({
    String? name,
    DateTime? createdAt,
    double? latitude,
    double? longitude,
  }) {
    return SheetMeta(
      id: id,
      name: name ?? this.name,
      createdAt: (createdAt ?? this.createdAt).toUtc(),
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toUtc().toIso8601String(), // ISO-8601 UTC (con 'Z')
    'latitude': latitude,
    'longitude': longitude,
  };

  static SheetMeta fromJson(Map<String, dynamic> j) {
    // Validaciones estrictas (id, name, createdAt son obligatorios)
    final dynamic rawId = j['id'];
    final dynamic rawName = j['name'];
    final dynamic rawCreatedAt = j['createdAt'];

    if (rawId == null || rawName == null || rawCreatedAt == null) {
      throw const FormatException(
        "El JSON para SheetMeta debe incluir 'id', 'name' y 'createdAt'.",
      );
    }
    if (rawId is! String || rawName is! String) {
      throw const FormatException("'id' y 'name' deben ser String.");
    }
    final createdAtParsed = DateTime.tryParse(rawCreatedAt.toString());
    if (createdAtParsed == null) {
      throw FormatException("Formato de fecha inválido: $rawCreatedAt");
    }

    return SheetMeta(
      id: rawId,
      name: rawName,
      createdAt: createdAtParsed.toUtc(),
      latitude: (j['latitude'] as num?)?.toDouble(),
      longitude: (j['longitude'] as num?)?.toDouble(),
    );
  }

  static String encodeList(List<SheetMeta> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<SheetMeta> decodeList(String s) {
    final raw = jsonDecode(s);
    if (raw is! List) {
      throw const FormatException('Se esperaba un JSON array para SheetMeta[].');
    }
    return raw.map<SheetMeta>((e) {
      if (e is! Map<String, dynamic>) {
        throw const FormatException('Cada item debe ser un objeto JSON.');
      }
      return SheetMeta.fromJson(e);
    }).toList();
  }
}
