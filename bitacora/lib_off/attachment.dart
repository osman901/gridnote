// lib/models/attachment.dart
import 'dart:convert';

enum AttachmentType { signature, photo, location }

class Attachment {
  final AttachmentType type;
  final String value; // path de imagen/firma o "lat,lon"
  final DateTime timestamp;

  const Attachment({
    required this.type,
    required this.value,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'type': type.name,
    'value': value,
    'ts': timestamp.toIso8601String(),
  };

  static Attachment fromMap(Map m) => Attachment(
    type: AttachmentType.values.firstWhere(
          (t) => t.name == (m['type'] ?? 'photo'),
      orElse: () => AttachmentType.photo,
    ),
    value: (m['value'] ?? '').toString(),
    timestamp:
    DateTime.tryParse((m['ts'] ?? '').toString()) ?? DateTime.now(),
  );

  static String encodeList(List<Attachment> list) =>
      jsonEncode(list.map((e) => e.toMap()).toList());

  static List<Attachment> decodeList(String raw) {
    try {
      final v = jsonDecode(raw);
      if (v is List) {
        return v.map((e) => Attachment.fromMap((e as Map).cast())).toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }
}
