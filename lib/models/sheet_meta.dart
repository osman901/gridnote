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
}
