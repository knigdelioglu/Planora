final class KanbanCard {
  const KanbanCard({
    required this.id,
    required this.boardId,
    required this.columnId,
    required this.title,
    required this.description,
    required this.rankKey,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required this.deletedAt,
  });

  final String id;
  final String boardId;
  final String columnId;
  final String title;
  final String? description;
  final String rankKey;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final DateTime? deletedAt;
}
