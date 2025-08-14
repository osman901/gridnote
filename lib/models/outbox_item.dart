import 'package:hive/hive.dart';

class OutboxHiveIds {
  static const int kind = 61;
  static const int item = 62;
}

/// Tipos de elemento a enviar.
enum OutboxKind { excel, pdf }

class OutboxKindAdapter extends TypeAdapter<OutboxKind> {
  @override
  final int typeId = OutboxHiveIds.kind;

  @override
  OutboxKind read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return OutboxKind.excel;
      case 1:
        return OutboxKind.pdf;
      default:
        return OutboxKind.excel; // fallback seguro
    }
  }

  @override
  void write(BinaryWriter writer, OutboxKind obj) {
    writer.writeByte(obj == OutboxKind.excel ? 0 : 1);
  }
}

/// Tu modelo (solo referencia de campos requeridos opcional/required)
class OutboxItem extends HiveObject {
  OutboxKind kind;
  String path;
  String filename;
  String? to;
  String? subject;
  String? text;
  int attempts;
  DateTime createdAt;
  DateTime? lastTryAt;

  OutboxItem({
    required this.kind,
    required this.path,
    required this.filename,
    this.to,
    this.subject,
    this.text,
    this.attempts = 0,
    DateTime? createdAt,
    this.lastTryAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class OutboxItemAdapter extends TypeAdapter<OutboxItem> {
  @override
  final int typeId = OutboxHiveIds.item;

  @override
  OutboxItem read(BinaryReader r) {
    final count = r.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < count; i++) r.readByte(): r.read(),
    };

    // Campos requeridos con validación
    final kind = fields[0] as OutboxKind?;
    final path = fields[1] as String?;
    final filename = fields[2] as String?;
    final createdAt = fields[7] as DateTime?;

    if (kind == null || path == null || filename == null || createdAt == null) {
      throw HiveError(
        'OutboxItem corrupto/incompleto: faltan campos requeridos (kind/path/filename/createdAt).',
      );
    }

    return OutboxItem(
      kind: kind,
      path: path,
      filename: filename,
      to: fields[3] as String?,
      subject: fields[4] as String?,
      text: fields[5] as String?,
      attempts: (fields[6] as int?) ?? 0,
      createdAt: createdAt,
      lastTryAt: fields[8] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter w, OutboxItem o) {
    // Map de campos -> el length es el conteo real (evita desincronización)
    final map = <int, dynamic>{
      0: o.kind,
      1: o.path,
      2: o.filename,
      3: o.to,
      4: o.subject,
      5: o.text,
      6: o.attempts,
      7: o.createdAt,
      8: o.lastTryAt,
    };

    w.writeByte(map.length);
    map.forEach((key, value) {
      w..writeByte(key)..write(value);
    });
  }
}
