class Sheet {
  final int? id;
  final String name;
  final DateTime createdAt;

  Sheet({this.id, required this.name, required this.createdAt});

  Sheet copyWith({int? id, String? name, DateTime? createdAt}) => Sheet(
      id: id ?? this.id, name: name ?? this.name, createdAt: createdAt ?? this.createdAt);
}

class Entry {
  final int? id;
  final int sheetId;
  final String? note;
  final double? lat;
  final double? lon;
  final String? photoPath;
  final DateTime updatedAt;

  Entry({
    this.id,
    required this.sheetId,
    this.note,
    this.lat,
    this.lon,
    this.photoPath,
    required this.updatedAt,
  });

  Entry copyWith({
    int? id,
    int? sheetId,
    String? note,
    double? lat,
    double? lon,
    String? photoPath,
    DateTime? updatedAt,
  }) =>
      Entry(
        id: id ?? this.id,
        sheetId: sheetId ?? this.sheetId,
        note: note ?? this.note,
        lat: lat ?? this.lat,
        lon: lon ?? this.lon,
        photoPath: photoPath ?? this.photoPath,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
