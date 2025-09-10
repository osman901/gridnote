// lib/models/free_sheet.dart
class FreeSheetData {
  String id;
  String name;
  DateTime createdAt;
  List<String> headers;
  List<List<String>> rows;

  FreeSheetData({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.headers,
    required this.rows,
  });

  void ensureWidth(int cols) {
    if (cols < 1) cols = 1;
    if (headers.length < cols) {
      headers.addAll(List.filled(cols - headers.length, ''));
    }
    for (final r in rows) {
      if (r.length < cols) {
        r.addAll(List.filled(cols - r.length, ''));
      }
    }
  }

  void ensureHeight(int count) {
    if (count < 0) count = 0;
    while (rows.length < count) {
      rows.add(List.filled(headers.length, ''));
    }
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'headers': headers,
    'rows': rows,
  };

  static FreeSheetData fromMap(Map map) => FreeSheetData(
    id: (map['id'] ?? '').toString(),
    name: (map['name'] ?? 'Planilla libre').toString(),
    createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
    headers: List<String>.from((map['headers'] as List?)?.map((e) => e?.toString() ?? '') ?? const []),
    rows: List<List>.from(map['rows'] as List? ?? const [])
        .map<List<String>>((r) => List<String>.from(r.map((e) => e?.toString() ?? '')))
        .toList(),
  );
}
