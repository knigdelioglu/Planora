import 'package:not_app/features/kanban/domain/repositories/kanban_repository.dart';

final class MoveCardUseCase {
  const MoveCardUseCase(this._repository);

  final KanbanRepository _repository;

  Future<void> call({
    required String cardId,
    required String destinationColumnId,
    required double rank,
  }) {
    return _repository.moveCard(
      cardId: cardId,
      destinationColumnId: destinationColumnId,
      rank: rank,
    );
  }
}
