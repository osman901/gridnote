// lib/models/note_model.dart
class Note {
  final String title;
  final String content;
  final String? imagePath;

  const Note({
    required this.title,
    required this.content,
    this.imagePath,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'content': content,
        'imagePath': imagePath,
      };

  factory Note.fromJson(Map<String, dynamic> json) {
    final t = json['title'];
    final c = json['content'];

    // Requeridos y con tipo correcto
    if (t == null || c == null) {
      throw const FormatException(
          'El JSON de Note debe incluir "title" y "content".');
    }
    if (t is! String || c is! String) {
      throw const FormatException('"title" y "content" deben ser String.');
    }

    // Normaliza y evita vacÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­os
    final title = t.trim();
    final content = c.trim();
    if (title.isEmpty || content.isEmpty) {
      throw const FormatException(
          '"title" y "content" no pueden estar vacÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­os.');
    }

    // imagePath es opcional
    final ip = json['imagePath'];
    return Note(
      title: title,
      content: content,
      imagePath: (ip is String && ip.trim().isNotEmpty) ? ip : null,
    );
  }
}
