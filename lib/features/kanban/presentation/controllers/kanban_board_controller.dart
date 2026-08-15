import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/features/kanban/domain/entities/kanban_card.dart';
import 'package:not_app/features/kanban/domain/repositories/kanban_repository.dart';
import 'package:not_app/features/kanban/domain/usecases/move_card_usecase.dart';

final kanbanRepositoryProvider = Provider<KanbanRepository>((ref) {
  throw UnimplementedError('KanbanRepository must be provided by app bootstrap.');
});

final boardCardsProvider = StreamProvider.family<List<KanbanCard>, String>((ref, boardId) {
  return ref.watch(kanbanRepositoryProvider).watchBoardCards(boardId);
});

final class KanbanBoardController {
  const KanbanBoardController(this._ref);

  final Ref _ref;

  Future<void> moveCard({
    required String cardId,
    required String destinationColumnId,
    required double rank,
  }) {
    final useCase = MoveCardUseCase(_ref.read(kanbanRepositoryProvider));
    return useCase(
      cardId: cardId,
      destinationColumnId: destinationColumnId,
      rank: rank,
    );
  }
}
