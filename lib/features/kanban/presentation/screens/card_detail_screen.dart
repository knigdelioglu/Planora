import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/features/attachments/presentation/attachments_section.dart';
import 'package:not_app/features/kanban/domain/entities/kanban_card.dart';
import 'package:not_app/features/kanban/domain/entities/kanban_snapshot.dart';
import 'package:not_app/features/reminders/presentation/reminder_widgets.dart';

class CardDetailScreen extends ConsumerStatefulWidget {
  const CardDetailScreen({super.key, required this.cardId});
  final String cardId;
  @override
  ConsumerState<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends ConsumerState<CardDetailScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  String? _loadedCardId;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save(KanbanCard card) async {
    await ref
        .read(kanbanRepositoryProvider)
        .updateCard(
          cardId: card.id,
          title: _title.text.trim(),
          description: _description.text.trim(),
        );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Kart cihazda kaydedildi.')));
    }
  }

  Future<void> _addAttachment() async {
    final file = await ref.read(filePickerServiceProvider).pickSingleFile();
    if (file == null) return;
    try {
      await ref
          .read(attachmentsRepositoryProvider)
          .addFromFile(
            parentType: 'card',
            parentId: widget.cardId,
            source: file,
          );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _addReminder(KanbanCard card) => createReminderForParent(
    context,
    ref,
    parentType: 'card',
    parentId: card.id,
    defaultTitle: _title.text.trim().isEmpty
        ? 'Kart hatırlatıcısı'
        : _title.text.trim(),
    defaultBody: _description.text.trim(),
  );

  Future<void> _moveToPrevColumn(
    KanbanCard card,
    KanbanSnapshot snapshot,
    int columnIndex,
  ) async {
    if (columnIndex <= 0) return;
    final prevColumn = snapshot.columns[columnIndex - 1];
    final targetIndex = snapshot.cardsByColumn[prevColumn.id]?.length ?? 0;
    await ref
        .read(kanbanRepositoryProvider)
        .moveCard(
          cardId: card.id,
          destinationColumnId: prevColumn.id,
          destinationIndex: targetIndex,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kart "${prevColumn.title}" kolonuna taşındı.')),
      );
    }
  }

  Future<void> _moveToNextColumn(
    KanbanCard card,
    KanbanSnapshot snapshot,
    int columnIndex,
  ) async {
    if (columnIndex < 0 || columnIndex >= snapshot.columns.length - 1) return;
    final nextColumn = snapshot.columns[columnIndex + 1];
    final targetIndex = snapshot.cardsByColumn[nextColumn.id]?.length ?? 0;
    await ref
        .read(kanbanRepositoryProvider)
        .moveCard(
          cardId: card.id,
          destinationColumnId: nextColumn.id,
          destinationIndex: targetIndex,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kart "${nextColumn.title}" kolonuna taşındı.')),
      );
    }
  }

  Future<void> _moveToTop(KanbanCard card) async {
    await ref
        .read(kanbanRepositoryProvider)
        .moveCard(
          cardId: card.id,
          destinationColumnId: card.columnId,
          destinationIndex: 0,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kart kolonun en üstüne taşındı.')),
      );
    }
  }

  Future<void> _moveToBottom(
    KanbanCard card,
    List<KanbanCard> cardsInColumn,
  ) async {
    final int targetIndex = (cardsInColumn.length - 1).clamp(0, 999999);
    await ref
        .read(kanbanRepositoryProvider)
        .moveCard(
          cardId: card.id,
          destinationColumnId: card.columnId,
          destinationIndex: targetIndex,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kart kolonun en altına taşındı.')),
      );
    }
  }

  Future<void> _confirmDelete(KanbanCard card) async {
    final bool ok =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Kart silinsin mi?'),
            content: const Text(
              'Kartla birlikte bağlı ekler ve hatırlatıcılar da kaldırılır.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sil'),
              ),
            ],
          ),
        ) ??
        false;
    if (ok) {
      await ref.read(kanbanRepositoryProvider).deleteCard(card.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(kanbanRepositoryProvider);
    return StreamBuilder<KanbanCard?>(
      stream: repo.watchCard(widget.cardId),
      builder: (context, cardSnapshot) {
        if (!cardSnapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Kart ayrıntısı')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final card = cardSnapshot.data;
        if (card == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Kart ayrıntısı')),
            body: const Center(child: Text('Kart bulunamadı.')),
          );
        }
        if (_loadedCardId != card.id) {
          _loadedCardId = card.id;
          _title.text = card.title;
          _description.text = card.description ?? '';
        }

        return StreamBuilder<KanbanSnapshot?>(
          stream: repo.watchBoard(card.boardId),
          builder: (context, boardSnapshot) {
            final boardData = boardSnapshot.data;
            int columnIndex = -1;
            List<KanbanCard> cardsInColumn = const <KanbanCard>[];
            int cardIndex = -1;
            bool hasPrev = false;
            bool hasNext = false;
            bool canMoveTop = false;
            bool canMoveBottom = false;
            String currentColumnTitle = '';

            if (boardData != null) {
              columnIndex = boardData.columns.indexWhere(
                (c) => c.id == card.columnId,
              );
              if (columnIndex != -1) {
                currentColumnTitle = boardData.columns[columnIndex].title;
                hasPrev = columnIndex > 0;
                hasNext = columnIndex < boardData.columns.length - 1;
                cardsInColumn =
                    boardData.cardsByColumn[card.columnId] ??
                    const <KanbanCard>[];
                cardIndex = cardsInColumn.indexWhere((c) => c.id == card.id);
                if (cardIndex != -1) {
                  canMoveTop = cardIndex > 0;
                  canMoveBottom = cardIndex < cardsInColumn.length - 1;
                }
              }
            }

            return Scaffold(
              appBar: AppBar(
                title: const Text('Kart ayrıntısı'),
                actions: <Widget>[
                  PopupMenuButton<String>(
                    key: const ValueKey<String>('card_detail_overflow_menu'),
                    tooltip: 'Kart seçenekleri',
                    onSelected: (value) async {
                      if (boardData == null || columnIndex == -1) return;
                      switch (value) {
                        case 'move_prev':
                          if (hasPrev) {
                            await _moveToPrevColumn(
                              card,
                              boardData,
                              columnIndex,
                            );
                          }
                          break;
                        case 'move_next':
                          if (hasNext) {
                            await _moveToNextColumn(
                              card,
                              boardData,
                              columnIndex,
                            );
                          }
                          break;
                        case 'move_top':
                          if (canMoveTop) await _moveToTop(card);
                          break;
                        case 'move_bottom':
                          if (canMoveBottom) {
                            await _moveToBottom(card, cardsInColumn);
                          }
                          break;
                        case 'delete':
                          await _confirmDelete(card);
                          break;
                      }
                    },
                    itemBuilder: (context) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        key: const ValueKey<String>('detail_menu_move_prev'),
                        value: 'move_prev',
                        enabled: hasPrev,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.arrow_back, size: 18),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Önceki kolona taşı',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        key: const ValueKey<String>('detail_menu_move_next'),
                        value: 'move_next',
                        enabled: hasNext,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.arrow_forward, size: 18),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Sonraki kolona taşı',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        key: const ValueKey<String>('detail_menu_move_top'),
                        value: 'move_top',
                        enabled: canMoveTop,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.vertical_align_top, size: 18),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Kolonun en üstüne taşı',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        key: const ValueKey<String>('detail_menu_move_bottom'),
                        value: 'move_bottom',
                        enabled: canMoveBottom,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.vertical_align_bottom, size: 18),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Kolonun en altına taşı',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem<String>(
                        key: ValueKey<String>('detail_menu_delete'),
                        value: 'delete',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.red,
                            ),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Sil',
                                style: TextStyle(color: Colors.red),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.all(24),
                children: <Widget>[
                  if (currentColumnTitle.isNotEmpty) ...<Widget>[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Chip(
                        avatar: const Icon(
                          Icons.view_column_outlined,
                          size: 16,
                        ),
                        label: Text('Kolon: $currentColumnTitle'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _title,
                    style: Theme.of(context).textTheme.headlineMedium,
                    decoration: const InputDecoration(labelText: 'Başlık'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _description,
                    minLines: 5,
                    maxLines: null,
                    decoration: const InputDecoration(labelText: 'Açıklama'),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: () => _save(card),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Kaydet'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _addAttachment,
                        icon: const Icon(Icons.attach_file),
                        label: const Text('Dosya ekle'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _addReminder(card),
                        icon: const Icon(Icons.notifications_none),
                        label: const Text('Hatırlatıcı'),
                      ),
                      TextButton.icon(
                        onPressed: () => _confirmDelete(card),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Sil'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Kartı taşı',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      OutlinedButton.icon(
                        key: const ValueKey<String>('detail_btn_move_prev'),
                        onPressed: hasPrev && boardData != null
                            ? () => _moveToPrevColumn(
                                card,
                                boardData,
                                columnIndex,
                              )
                            : null,
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const Text('Önceki kolona taşı'),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey<String>('detail_btn_move_next'),
                        onPressed: hasNext && boardData != null
                            ? () => _moveToNextColumn(
                                card,
                                boardData,
                                columnIndex,
                              )
                            : null,
                        icon: const Icon(Icons.arrow_forward, size: 18),
                        label: const Text('Sonraki kolona taşı'),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey<String>('detail_btn_move_top'),
                        onPressed: canMoveTop ? () => _moveToTop(card) : null,
                        icon: const Icon(Icons.vertical_align_top, size: 18),
                        label: const Text('Kolonun en üstüne taşı'),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey<String>('detail_btn_move_bottom'),
                        onPressed: canMoveBottom
                            ? () => _moveToBottom(card, cardsInColumn)
                            : null,
                        icon: const Icon(Icons.vertical_align_bottom, size: 18),
                        label: const Text('Kolonun en altına taşı'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text('Ekler', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  AttachmentsSection(parentType: 'card', parentId: card.id),
                  const SizedBox(height: 28),
                  Text(
                    'Hatırlatıcılar',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  ReminderList(parentType: 'card', parentId: card.id),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
