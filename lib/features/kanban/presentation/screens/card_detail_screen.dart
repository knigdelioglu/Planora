import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/app/widgets/navigation/app_toolbar.dart';
import 'package:not_app/features/attachments/presentation/attachments_section.dart';
import 'package:not_app/features/kanban/domain/entities/kanban_card.dart';
import 'package:not_app/features/kanban/domain/entities/kanban_snapshot.dart';
import 'package:not_app/features/notes/presentation/widgets/linked_notes_section.dart';
import 'package:not_app/features/reminders/presentation/reminder_widgets.dart';
import 'package:not_app/features/tags/domain/entities/tag.dart';
import 'package:not_app/features/tags/presentation/widgets/tag_strip.dart';

class CardDetailScreen extends StatelessWidget {
  const CardDetailScreen({super.key, required this.cardId});

  final String cardId;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: <Widget>[
        AppToolbar(
          title: 'Kart ayrıntısı',
          leading: IconButton(
            tooltip: 'Geri',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        Expanded(child: CardDetailPane(cardId: cardId)),
      ],
    ),
  );
}

class CardDetailPane extends ConsumerStatefulWidget {
  const CardDetailPane({
    super.key,
    required this.cardId,
    this.onClose,
    this.embedded = false,
  });

  final String cardId;
  final VoidCallback? onClose;
  final bool embedded;

  @override
  ConsumerState<CardDetailPane> createState() => _CardDetailPaneState();
}

class _CardDetailPaneState extends ConsumerState<CardDetailPane> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  Timer? _saveTimer;
  String? _loadedCardId;
  bool _hydrating = false;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _title.addListener(_scheduleSave);
    _description.addListener(_scheduleSave);
  }

  @override
  void didUpdateWidget(covariant CardDetailPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cardId != widget.cardId) {
      _loadedCardId = null;
      _saveTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  void _hydrate(KanbanCard card) {
    if (_loadedCardId == card.id) return;
    _hydrating = true;
    _loadedCardId = card.id;
    _title.text = card.title;
    _description.text = card.description ?? '';
    _hydrating = false;
  }

  void _scheduleSave() {
    if (_hydrating || _loadedCardId == null) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _save);
  }

  Future<void> _save() async {
    final String? cardId = _loadedCardId;
    if (cardId == null) return;
    if (mounted) setState(() => _saving = true);
    try {
      await ref
          .read(kanbanRepositoryProvider)
          .updateCard(
            cardId: cardId,
            title: _title.text.trim(),
            description: _description.text.trim(),
          );
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = error.toString();
        });
      }
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
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
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

  Future<void> _moveColumn(
    KanbanCard card,
    KanbanSnapshot board,
    String destinationColumnId,
  ) async {
    if (destinationColumnId == card.columnId) return;
    final int destinationIndex =
        board.cardsByColumn[destinationColumnId]?.length ?? 0;
    await ref
        .read(kanbanRepositoryProvider)
        .moveCard(
          cardId: card.id,
          destinationColumnId: destinationColumnId,
          destinationIndex: destinationIndex,
        );
  }

  Future<void> _confirmDelete(KanbanCard card) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Kart silinsin mi?'),
            content: const Text(
              'Kart ve bağlı ekleri ile hatırlatıcıları kaldırılacak.',
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
    if (!confirmed) return;
    await ref.read(kanbanRepositoryProvider).deleteCard(card.id);
    if (!mounted) return;
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      unawaited(Navigator.of(context).maybePop());
    }
  }

  String get _saveLabel {
    if (_saving) return 'Kaydediliyor…';
    if (_saveError != null) return 'Kaydetme sorunu';
    return 'Bu cihazda kaydedildi';
  }

  IconData get _saveIcon {
    if (_saving) return Icons.sync_rounded;
    if (_saveError != null) return Icons.error_outline_rounded;
    return Icons.check_circle_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(kanbanRepositoryProvider);
    return StreamBuilder<KanbanCard?>(
      stream: repo.watchCard(widget.cardId),
      builder: (context, cardSnapshot) {
        final KanbanCard? card = cardSnapshot.data;
        if (cardSnapshot.connectionState == ConnectionState.waiting &&
            card == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (card == null) {
          return const Center(child: Text('Kart bulunamadı.'));
        }
        _hydrate(card);

        return StreamBuilder<KanbanSnapshot?>(
          stream: repo.watchBoard(card.boardId),
          builder: (context, boardSnapshot) {
            final KanbanSnapshot? board = boardSnapshot.data;
            return Column(
              children: <Widget>[
                if (widget.embedded)
                  _EmbeddedHeader(
                    title: 'Kart ayrıntısı',
                    saveLabel: _saveLabel,
                    saveIcon: _saveIcon,
                    onClose: widget.onClose,
                    onDelete: () => _confirmDelete(card),
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
                    children: <Widget>[
                      TextField(
                        controller: _title,
                        maxLines: null,
                        style: Theme.of(context).textTheme.headlineMedium,
                        decoration: const InputDecoration(
                          hintText: 'Kart başlığı',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: <Widget>[
                          Icon(
                            _saveIcon,
                            size: 14,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _saveLabel,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const Spacer(),
                          PopupMenuButton<String>(
                            tooltip: 'Kart işlemleri',
                            onSelected: (value) {
                              if (value == 'delete') {
                                unawaited(_confirmDelete(card));
                              }
                            },
                            itemBuilder: (_) => const <PopupMenuEntry<String>>[
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Kartı sil'),
                              ),
                            ],
                            icon: const Icon(
                              Icons.more_horiz_rounded,
                              size: 19,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TagStrip(
                        targetType: TagTargetType.card,
                        targetId: card.id,
                      ),
                      const SizedBox(height: 18),
                      if (board != null)
                        DropdownButtonFormField<String>(
                          initialValue: card.columnId,
                          decoration: const InputDecoration(
                            labelText: 'Kolon',
                            prefixIcon: Icon(
                              Icons.view_column_outlined,
                              size: 19,
                            ),
                          ),
                          items: board.columns
                              .map(
                                (column) => DropdownMenuItem<String>(
                                  value: column.id,
                                  child: Text(column.title),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value != null) {
                              unawaited(_moveColumn(card, board, value));
                            }
                          },
                        ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _description,
                        minLines: 5,
                        maxLines: null,
                        decoration: const InputDecoration(
                          labelText: 'Açıklama',
                          hintText: 'Kartla ilgili ayrıntıları yazın…',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 18),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(bottom: 12),
                        title: const Text('Bağlı notlar'),
                        leading: const Icon(
                          Icons.description_outlined,
                          size: 19,
                        ),
                        children: <Widget>[
                          LinkedNotesSection(cardId: card.id),
                        ],
                      ),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(bottom: 12),
                        title: const Text('Ekler'),
                        leading: const Icon(
                          Icons.attach_file_rounded,
                          size: 19,
                        ),
                        trailing: IconButton(
                          tooltip: 'Dosya ekle',
                          onPressed: _addAttachment,
                          icon: const Icon(Icons.add_rounded, size: 18),
                        ),
                        children: <Widget>[
                          AttachmentsSection(
                            parentType: 'card',
                            parentId: card.id,
                            emptyText: 'Ek dosya yok.',
                          ),
                        ],
                      ),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(bottom: 12),
                        title: const Text('Hatırlatıcılar'),
                        leading: const Icon(
                          Icons.notifications_none_rounded,
                          size: 19,
                        ),
                        trailing: IconButton(
                          tooltip: 'Hatırlatıcı ekle',
                          onPressed: () => _addReminder(card),
                          icon: const Icon(Icons.add_rounded, size: 18),
                        ),
                        children: <Widget>[
                          ReminderList(parentType: 'card', parentId: card.id),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _EmbeddedHeader extends StatelessWidget {
  const _EmbeddedHeader({
    required this.title,
    required this.saveLabel,
    required this.saveIcon,
    required this.onClose,
    required this.onDelete,
  });

  final String title;
  final String saveLabel;
  final IconData saveIcon;
  final VoidCallback? onClose;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
    ),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 2),
              Row(
                children: <Widget>[
                  Icon(saveIcon, size: 13),
                  const SizedBox(width: 4),
                  Text(saveLabel, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Kart işlemleri',
          onSelected: (value) {
            if (value == 'delete') onDelete();
          },
          itemBuilder: (_) => const <PopupMenuEntry<String>>[
            PopupMenuItem(value: 'delete', child: Text('Kartı sil')),
          ],
          icon: const Icon(Icons.more_horiz_rounded, size: 19),
        ),
        IconButton(
          tooltip: 'Kapat',
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
  );
}
