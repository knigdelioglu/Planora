import 'package:not_app/features/kanban/domain/entities/kanban_card.dart';

abstract interface class KanbanLocalDataSource {
  Stream<List<KanbanCard>> watchBoardCards(String boardId);

  /// Must run card mutation and sync-queue insertion in one DB transaction.
  Future<void> moveCardAndEnqueue({
    required String cardId,
    required String destinationColumnId,
    required double rank,
  });
}
