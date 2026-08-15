final class BoardEntity {
  const BoardEntity({
    required this.id,
    required this.title,
    required this.colorHex,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required this.deletedAt,
  });

  final String id;
  final String title;
  final String? colorHex;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final DateTime? deletedAt;
}
