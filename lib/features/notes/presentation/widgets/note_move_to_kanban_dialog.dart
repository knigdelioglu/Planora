import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/features/kanban/domain/entities/board.dart';
import 'package:not_app/features/kanban/domain/entities/kanban_card.dart';
import 'package:not_app/features/kanban/domain/entities/kanban_snapshot.dart';
import 'package:not_app/features/notes/domain/entities/note.dart';

Future<bool> showMoveNoteToKanbanDialog(
  BuildContext context, {
  required NoteEntity note,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (_) => _MoveNoteToKanbanDialog(note: note),
      ) ??
      false;
}

class _MoveNoteToKanbanDialog extends ConsumerStatefulWidget {
  const _MoveNoteToKanbanDialog({required this.note});

  final NoteEntity note;

  @override
  ConsumerState<_MoveNoteToKanbanDialog> createState() =>
      _MoveNoteToKanbanDialogState();
}

class _MoveNoteToKanbanDialogState
    extends ConsumerState<_MoveNoteToKanbanDialog> {
  static const String _newCard = '__new_card__';

  String? _boardId;
  String? _columnId;
  String? _cardTarget = _newCard;
  bool _saving = false;
  String? _error;

  Future<void> _submit(KanbanSnapshot snapshot) async {
    final String? boardId = _boardId;
    final String? columnId = _columnId;
    final String? cardTarget = _cardTarget;
    if (boardId == null || columnId == null || cardTarget == null || _saving) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = ref.read(noteKanbanRepositoryProvider);
      if (cardTarget == _newCard) {
        await repository.moveNoteToColumn(
          noteId: widget.note.id,
          boardId: boardId,
          columnId: columnId,
          title: widget.note.title,
        );
      } else {
        final List<KanbanCard> cards =
            snapshot.cardsByColumn[columnId] ?? const <KanbanCard>[];
        if (!cards.any((card) => card.id == cardTarget)) {
          throw StateError('Hedef kart artık mevcut değil.');
        }
        await repository.moveNoteToCard(
          noteId: widget.note.id,
          cardId: cardTarget,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final kanban = ref.watch(kanbanRepositoryProvider);
    return AlertDialog(
      title: const Text('Panoya taşı'),
      content: SizedBox(
        width: 460,
        child: StreamBuilder<List<BoardEntity>>(
          stream: kanban.watchBoards(),
          builder: (context, boardsSnapshot) {
            if (boardsSnapshot.hasError) {
              return Text(boardsSnapshot.error.toString());
            }
            if (!boardsSnapshot.hasData) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final List<BoardEntity> boards = boardsSnapshot.requireData;
            if (boards.isEmpty) {
              return const Text(
                'Önce bir pano ve kolon oluşturmanız gerekiyor.',
              );
            }
            final String? selectedBoardId =
                boards.any((board) => board.id == _boardId) ? _boardId : null;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                DropdownButtonFormField<String>(
                  initialValue: selectedBoardId,
                  decoration: const InputDecoration(
                    labelText: 'Pano',
                    prefixIcon: Icon(Icons.dashboard_outlined),
                  ),
                  items: boards
                      .map(
                        (board) => DropdownMenuItem<String>(
                          value: board.id,
                          child: Text(board.title),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _saving
                      ? null
                      : (value) {
                          setState(() {
                            _boardId = value;
                            _columnId = null;
                            _cardTarget = _newCard;
                            _error = null;
                          });
                        },
                ),
                const SizedBox(height: 14),
                if (selectedBoardId != null)
                  StreamBuilder<KanbanSnapshot?>(
                    stream: kanban.watchBoard(selectedBoardId),
                    builder: (context, boardSnapshot) {
                      if (!boardSnapshot.hasData) {
                        return const SizedBox(
                          height: 88,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final KanbanSnapshot? snapshot = boardSnapshot.data;
                      if (snapshot == null || snapshot.columns.isEmpty) {
                        return const Text(
                          'Bu panoda hedef olarak seçilebilecek kolon yok.',
                        );
                      }
                      final String? selectedColumnId = snapshot.columns.any(
                        (column) => column.id == _columnId,
                      )
                          ? _columnId
                          : null;
                      final List<KanbanCard> cards = selectedColumnId == null
                          ? const <KanbanCard>[]
                          : snapshot.cardsByColumn[selectedColumnId] ??
                                const <KanbanCard>[];
                      final bool validCardTarget =
                          _cardTarget == _newCard ||
                          cards.any((card) => card.id == _cardTarget);
                      final String? selectedCardTarget = selectedColumnId == null
                          ? null
                          : validCardTarget
                          ? _cardTarget
                          : _newCard;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          DropdownButtonFormField<String>(
                            initialValue: selectedColumnId,
                            decoration: const InputDecoration(
                              labelText: 'Kolon',
                              prefixIcon: Icon(Icons.view_column_outlined),
                            ),
                            items: snapshot.columns
                                .map(
                                  (column) => DropdownMenuItem<String>(
                                    value: column.id,
                                    child: Text(column.title),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: _saving
                                ? null
                                : (value) {
                                    setState(() {
                                      _columnId = value;
                                      _cardTarget = _newCard;
                                      _error = null;
                                    });
                                  },
                          ),
                          if (selectedColumnId != null) ...<Widget>[
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              initialValue: selectedCardTarget,
                              decoration: const InputDecoration(
                                labelText: 'Hedef',
                                prefixIcon: Icon(Icons.crop_portrait_rounded),
                              ),
                              items: <DropdownMenuItem<String>>[
                                const DropdownMenuItem<String>(
                                  value: _newCard,
                                  child: Text('Yeni kart olarak ekle'),
                                ),
                                ...cards.map(
                                  (card) => DropdownMenuItem<String>(
                                    value: card.id,
                                    child: Text(card.title),
                                  ),
                                ),
                              ],
                              onChanged: _saving
                                  ? null
                                  : (value) =>
                                        setState(() => _cardTarget = value),
                            ),
                          ],
                          if (_error != null) ...<Widget>[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed:
                                  selectedColumnId == null || _saving
                                  ? null
                                  : () => unawaited(_submit(snapshot)),
                              icon: _saving
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.drive_file_move_outline),
                              label: Text(
                                _saving ? 'Taşınıyor…' : 'Panoya taşı',
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Vazgeç'),
        ),
      ],
    );
  }
}
