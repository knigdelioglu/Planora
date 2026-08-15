final class BoardColumnEntity {
  const BoardColumnEntity({
    required this.id,
    required this.boardId,
    required this.title,
    required this.colorHex,
    required this.rankKey,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required this.deletedAt,
  });

  final String id;
  final String boardId;
  final String title;
  final String? colorHex;
  final String rankKey;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final DateTime? deletedAt;
}
