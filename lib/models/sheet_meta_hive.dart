// lib/models/sheet_meta_hive.dart
import 'package:hive/hive.dart';

/// ¡Adapter manual, sin build_runner!
/// Asegurate de que 'typeId' no choque con otros adapters de tu app.
const int _kSheetMetaTypeId = 31;

class SheetMetaHive {
  SheetMetaHive({
    required this.id,
    required this.name,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.latitude,
    this.longitude,
    this.author, // <-- NUEVO
  });

  String id;
  String name;
  DateTime createdAtUtc;
  DateTime updatedAtUtc;
  double? latitude;
  double? longitude;
  String? author; // <-- NUEVO
}

class SheetMetaHiveAdapter extends TypeAdapter<SheetMetaHive> {
  @override
  final int typeId = _kSheetMetaTypeId;

  @override
  SheetMetaHive read(BinaryReader reader) {
    final n = reader.readByte();
    final f = <int, dynamic>{};
    for (var i = 0; i < n; i++) {
      f[reader.readByte()] = reader.read();
    }
    return SheetMetaHive(
      id: f[0] as String,
      name: f[1] as String,
      createdAtUtc: f[2] as DateTime,
      updatedAtUtc: f[3] as DateTime,
      latitude: (f[4] as num?)?.toDouble(),
      longitude: (f[5] as num?)?.toDouble(),
      author: f[6] as String?, // <-- tolera null si el registro es viejo
    );
  }

  @override
  void write(BinaryWriter writer, SheetMetaHive obj) {
    writer
      ..writeByte(7) // <-- antes era 6; sumamos 'author'
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.createdAtUtc)
      ..writeByte(3)
      ..write(obj.updatedAtUtc)
      ..writeByte(4)
      ..write(obj.latitude)
      ..writeByte(5)
      ..write(obj.longitude)
      ..writeByte(6)
      ..write(obj.author); // <-- NUEVO
  }
}

