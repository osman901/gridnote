// lib/models/sheet_meta_hive.dart
import 'package:hive/hive.dart';
import 'sheet_meta.dart';

/// Modelo persistible en Hive para `SheetMeta`.
class SheetMetaHive {
  SheetMetaHive({
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

  static SheetMetaHive from(SheetMeta m) => SheetMetaHive(
    id: m.id,
    name: m.name,
    createdAt: m.createdAt,
    updatedAt: m.updatedAt,
    latitude: m.latitude,
    longitude: m.longitude,
    author: m.author,
  );

  SheetMeta toSheetMeta() => SheetMeta(
    id: id,
    name: name,
    createdAt: createdAt,
    updatedAt: updatedAt,
    latitude: latitude,
    longitude: longitude,
    author: author,
  );
}

/// TypeAdapter manual (no usa build_runner).
class SheetMetaHiveAdapter extends TypeAdapter<SheetMetaHive> {
  @override
  final int typeId = 21;

  @override
  SheetMetaHive read(BinaryReader reader) {
    final ver = reader.readByte(); // reservado para migraciones (1)
    final id = reader.readString();
    final name = reader.readString();
    final createdAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final updatedAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final hasLat = reader.readBool();
    final lat = hasLat ? reader.readDouble() : null;
    final hasLng = reader.readBool();
    final lng = hasLng ? reader.readDouble() : null;
    final hasAuthor = reader.readBool();
    final author = hasAuthor ? reader.readString() : null;

    return SheetMetaHive(
      id: id,
      name: name,
      createdAt: createdAt,
      updatedAt: updatedAt,
      latitude: lat,
      longitude: lng,
      author: author,
    );
  }

  @override
  void write(BinaryWriter writer, SheetMetaHive obj) {
    writer
      ..writeByte(1)
      ..writeString(obj.id)
      ..writeString(obj.name)
      ..writeInt(obj.createdAt.millisecondsSinceEpoch)
      ..writeInt(obj.updatedAt.millisecondsSinceEpoch)
      ..writeBool(obj.latitude != null);
    if (obj.latitude != null) writer.writeDouble(obj.latitude!);
    writer..writeBool(obj.longitude != null);
    if (obj.longitude != null) writer.writeDouble(obj.longitude!);
    writer..writeBool(obj.author != null);
    if (obj.author != null) writer.writeString(obj.author!);
  }
}
