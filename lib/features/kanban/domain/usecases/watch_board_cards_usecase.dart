import 'package:not_app/features/kanban/domain/entities/kanban_card.dart';
import 'package:not_app/features/kanban/domain/repositories/kanban_repository.dart';

final class WatchBoardCardsUseCase {
  const WatchBoardCardsUseCase(this._repository);

  final KanbanRepository _repository;

  Stream<List<KanbanCard>> call(String boardId) =>
      repository.watchBoardCards(boardId);

  KanbanRepository get repository => _repository;
}
