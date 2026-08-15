import 'package:not_app/features/kanban/domain/entities/board.dart';
import 'package:not_app/features/kanban/domain/entities/board_column.dart';
import 'package:not_app/features/kanban/domain/entities/kanban_card.dart';

final class KanbanSnapshot {
  const KanbanSnapshot({
    required this.board,
    required this.columns,
    required this.cardsByColumn,
  });

  final BoardEntity board;
  final List<BoardColumnEntity> columns;
  final Map<String, List<KanbanCard>> cardsByColumn;
}
