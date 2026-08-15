class Board {
  const Board({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
}
