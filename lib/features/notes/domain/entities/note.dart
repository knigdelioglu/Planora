class Note {
  const Note({
    required this.id,
    required this.title,
    required this.contentJson,
    required this.updatedAt,
    required this.version,
  });

  final String id;
  final String title;
  final String contentJson;
  final DateTime updatedAt;
  final int version;
}
