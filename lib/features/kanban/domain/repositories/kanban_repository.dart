import 'package:not_app/features/kanban/domain/entities/board.dart';
import 'package:not_app/features/kanban/domain/entities/kanban_snapshot.dart';
import 'package:not_app/features/kanban/domain/entities/kanban_card.dart';

abstract interface class KanbanRepository {
  Stream<List<BoardEntity>> watchBoards();
  Stream<KanbanSnapshot?> watchBoard(String boardId);
  Stream<KanbanCard?> watchCard(String cardId);
  Future<String> createBoard({required String title, String? colorHex});
  Future<void> renameBoard(String boardId, String title);
  Future<void> deleteBoard(String boardId);
  Future<String> createColumn({
    required String boardId,
    required String title,
    String? colorHex,
  });
  Future<void> renameColumn(String columnId, String title);
  Future<void> reorderColumn({
    required String columnId,
    required int destinationIndex,
  });
  Future<void> deleteColumn(String columnId, {String? moveCardsToColumnId});
  Future<String> createCard({
    required String boardId,
    required String columnId,
    required String title,
    String? description,
  });
  Future<void> updateCard({
    required String cardId,
    required String title,
    String? description,
  });
  Future<void> moveCard({
    required String cardId,
    required String destinationColumnId,
    required int destinationIndex,
  });
  Future<void> deleteCard(String cardId);
}
