import 'package:not_app/features/kanban/domain/entities/kanban_card.dart';

abstract interface class KanbanRepository {
  Stream<List<KanbanCard>> watchBoardCards(String boardId);

  /// Updates the local card and enqueues the remote sync operation atomically.
  Future<void> moveCard({
    required String cardId,
    required String destinationColumnId,
    required double rank,
  });
}
