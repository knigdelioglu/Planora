import 'package:not_app/features/kanban/data/datasources/kanban_local_datasource.dart';
import 'package:not_app/features/kanban/domain/entities/kanban_card.dart';
import 'package:not_app/features/kanban/domain/repositories/kanban_repository.dart';

final class KanbanRepositoryImpl implements KanbanRepository {
  const KanbanRepositoryImpl(this._local);

  final KanbanLocalDataSource _local;

  @override
  Stream<List<KanbanCard>> watchBoardCards(String boardId) =>
      _local.watchBoardCards(boardId);

  @override
  Future<void> moveCard({
    required String cardId,
    required String destinationColumnId,
    required double rank,
  }) {
    return _local.moveCardAndEnqueue(
      cardId: cardId,
      destinationColumnId: destinationColumnId,
      rank: rank,
    );
  }
}
