class KanbanCard {
  const KanbanCard({
    required this.id,
    required this.boardId,
    required this.columnId,
    required this.title,
    required this.rank,
    required this.updatedAt,
    required this.version,
    this.description,
  });

  final String id;
  final String boardId;
  final String columnId;
  final String title;
  final String? description;
  final double rank;
  final DateTime updatedAt;
  final int version;

  KanbanCard copyWith({
    String? columnId,
    double? rank,
    DateTime? updatedAt,
    int? version,
  }) {
    return KanbanCard(
      id: id,
      boardId: boardId,
      columnId: columnId ?? this.columnId,
      title: title,
      description: description,
      rank: rank ?? this.rank,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
    );
  }
}
