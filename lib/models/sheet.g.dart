// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sheet.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SheetMetaAdapter extends TypeAdapter<SheetMeta> {
  @override
  final int typeId = 100;

  @override
  SheetMeta read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SheetMeta(
      id: fields[0] as String,
      name: fields[1] as String,
      createdAt: fields[2] as DateTime,
      updatedAt: fields[3] as DateTime,
      lat: fields[4] as double?,
      lon: fields[5] as double?,
      cloudUrl: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SheetMeta obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.updatedAt)
      ..writeByte(4)
      ..write(obj.lat)
      ..writeByte(5)
      ..write(obj.lon)
      ..writeByte(6)
      ..write(obj.cloudUrl);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SheetMetaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
