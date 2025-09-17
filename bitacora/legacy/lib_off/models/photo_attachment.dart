class PhotoAttachment {
  final String path;
  final DateTime createdAt;
  final String? note; // opcional (por ej. progresiva)

  const PhotoAttachment({
    required this.path,
    required this.createdAt,
    this.note,
  });
}
