import 'package:not_app/features/attachments/domain/repositories/attachments_repository.dart';
import 'package:not_app/features/kanban/domain/entities/board.dart';
import 'package:not_app/features/kanban/domain/entities/kanban_card.dart';
import 'package:not_app/features/kanban/domain/entities/kanban_snapshot.dart';
import 'package:not_app/features/kanban/domain/repositories/kanban_repository.dart';
import 'package:not_app/features/reminders/domain/repositories/reminders_repository.dart';

final class LifecycleKanbanRepository implements KanbanRepository {
  LifecycleKanbanRepository({
    required KanbanRepository delegate,
    required AttachmentsRepository attachments,
    required RemindersRepository reminders,
  }) : _delegate = delegate,
       _attachments = attachments,
       _reminders = reminders;

  final KanbanRepository _delegate;
  final AttachmentsRepository _attachments;
  final RemindersRepository _reminders;

  @override
  Stream<List<BoardEntity>> watchBoards() => _delegate.watchBoards();

  @override
  Stream<KanbanSnapshot?> watchBoard(String boardId) =>
      _delegate.watchBoard(boardId);

  @override
  Stream<KanbanCard?> watchCard(String cardId) => _delegate.watchCard(cardId);

  @override
  Future<String> createBoard({required String title, String? colorHex}) =>
      _delegate.createBoard(title: title, colorHex: colorHex);

  @override
  Future<void> renameBoard(String boardId, String title) =>
      _delegate.renameBoard(boardId, title);

  @override
  Future<void> deleteBoard(String boardId) async {
    final KanbanSnapshot? snapshot = await _delegate.watchBoard(boardId).first;
    if (snapshot != null) {
      final List<KanbanCard> cards = snapshot.cardsByColumn.values
          .expand((items) => items)
          .toList(growable: false);
      for (final KanbanCard card in cards) {
        await _deleteChildren('card', card.id);
      }
    }
    await _delegate.deleteBoard(boardId);
  }

  @override
  Future<String> createColumn({
    required String boardId,
    required String title,
    String? colorHex,
  }) => _delegate.createColumn(
    boardId: boardId,
    title: title,
    colorHex: colorHex,
  );

  @override
  Future<void> renameColumn(String columnId, String title) =>
      _delegate.renameColumn(columnId, title);

  @override
  Future<void> reorderColumn({
    required String columnId,
    required int destinationIndex,
  }) => _delegate.reorderColumn(
    columnId: columnId,
    destinationIndex: destinationIndex,
  );

  @override
  Future<void> deleteColumn(
    String columnId, {
    String? moveCardsToColumnId,
  }) => _delegate.deleteColumn(
    columnId,
    moveCardsToColumnId: moveCardsToColumnId,
  );

  @override
  Future<String> createCard({
    required String boardId,
    required String columnId,
    required String title,
    String? description,
  }) => _delegate.createCard(
    boardId: boardId,
    columnId: columnId,
    title: title,
    description: description,
  );

  @override
  Future<void> updateCard({
    required String cardId,
    required String title,
    String? description,
  }) => _delegate.updateCard(
    cardId: cardId,
    title: title,
    description: description,
  );

  @override
  Future<void> moveCard({
    required String cardId,
    required String destinationColumnId,
    required int destinationIndex,
  }) => _delegate.moveCard(
    cardId: cardId,
    destinationColumnId: destinationColumnId,
    destinationIndex: destinationIndex,
  );

  @override
  Future<void> deleteCard(String cardId) async {
    await _deleteChildren('card', cardId);
    await _delegate.deleteCard(cardId);
  }

  Future<void> _deleteChildren(String parentType, String parentId) async {
    final attachments = await _attachments
        .watchForParent(parentType, parentId)
        .first;
    for (final attachment in attachments) {
      await _attachments.remove(attachment.id);
    }
    final reminders = await _reminders
        .watchForParent(parentType, parentId)
        .first;
    for (final reminder in reminders) {
      await _reminders.remove(reminder.id);
    }
  }
}
