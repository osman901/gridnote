import 'dart:convert';

class FreeSheetData {
  FreeSheetData({
    required this.id,
    required this.name,
    List<String>? headers,
    List<List<String>>? rows,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : headers = headers ?? <String>[],
        rows = rows ?? <List<String>>[],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String name;
  final DateTime createdAt;
  DateTime updatedAt;

  /// Encabezados de columnas
  final List<String> headers;

  /// Filas (cada fila tiene la misma cantidad de columnas que [headers])
  final List<List<String>> rows;

  /// Garantiza al menos [minCols] columnas. Rellena headers y filas.
  void ensureWidth(int minCols) {
    while (headers.length < minCols) {
      headers.add('Col ${headers.length + 1}');
    }
    for (final r in rows) {
      if (r.length < headers.length) {
        r.addAll(List.filled(headers.length - r.length, ''));
      }
    }
  }

  /// Garantiza al menos [minRows] filas (vacías).
  void ensureHeight(int minRows) {
    while (rows.length < minRows) {
      rows.add(List.filled(headers.length, ''));
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'headers': headers,
    'rows': rows,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  static FreeSheetData fromJson(Map<String, dynamic> json) => FreeSheetData(
    id: json['id'] as String,
    name: json['name'] as String? ?? 'Planilla',
    headers: (json['headers'] as List?)?.cast<String>() ?? <String>[],
    rows: ((json['rows'] as List?) ?? const <dynamic>[])
        .map<List<String>>((e) => (e as List?)?.cast<String>() ?? <String>[])
        .toList(),
    createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
  );

  String encode() => jsonEncode(toJson());
  static FreeSheetData decode(String src) =>
      fromJson(jsonDecode(src) as Map<String, dynamic>);
}
