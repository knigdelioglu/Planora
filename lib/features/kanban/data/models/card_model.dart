import 'package:not_app/features/kanban/domain/entities/kanban_card.dart';

final class CardModel {
  const CardModel({
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

  KanbanCard toEntity() => KanbanCard(
    id: id,
    boardId: boardId,
    columnId: columnId,
    title: title,
    description: description,
    rank: rank,
    updatedAt: updatedAt,
    version: version,
  );
}
