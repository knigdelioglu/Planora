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
    await ref.read(kanbanRepositoryProvider).updateCard(
          cardId: card.id,
          title: _title.text.trim(),
          description: _description.text.trim(),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kart cihazda kaydedildi.')),
    );
  }

  Future<void> _addAttachment() async {
    final file = await ref.read(filePickerServiceProvider).pickSingleFile();
    if (file == null) return;
    try {
      await ref.read(attachmentsRepositoryProvider).addFromFile(
            parentType: 'card',
            parentId: widget.cardId,
            source: file,
          );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
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

  Future<void> _confirmDelete(KanbanCard card) async {
    final bool confirmed =
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
    if (!confirmed) return;

    await ref.read(kanbanRepositoryProvider).deleteCard(card.id);
    if (mounted) Navigator.pop(context);
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
          return Scaffold(
            appBar: AppBar(title: const Text('Kart ayrıntısı')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
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
            final KanbanSnapshot? board = boardSnapshot.data;
            String? columnTitle;
            if (board != null) {
              for (final column in board.columns) {
                if (column.id == card.columnId) {
                  columnTitle = column.title;
                  break;
                }
              }
            }

            return Scaffold(
              appBar: AppBar(
                title: const Text('Kart ayrıntısı'),
                actions: <Widget>[
                  PopupMenuButton<String>(
                    tooltip: 'Kart seçenekleri',
                    onSelected: (value) async {
                      if (value == 'delete') {
                        await _confirmDelete(card);
                      }
                    },
                    itemBuilder: (_) => const <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
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
                            Text(
                              'Kartı sil',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              body: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
                    children: <Widget>[
                      if (columnTitle != null && columnTitle.isNotEmpty) ...<Widget>[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Chip(
                            avatar: const Icon(
                              Icons.view_column_outlined,
                              size: 16,
                            ),
                            label: Text(columnTitle),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: _title,
                        style: Theme.of(context).textTheme.headlineMedium,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Başlık',
                          hintText: 'Kart başlığı',
                        ),
                      ),
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 16),
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
                        ],
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Ekler',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      AttachmentsSection(
                        parentType: 'card',
                        parentId: card.id,
                        emptyText: 'Ek dosya yok.',
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Hatırlatıcılar',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      ReminderList(parentType: 'card', parentId: card.id),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
