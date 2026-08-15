import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/features/attachments/domain/entities/attachment.dart';
import 'package:not_app/features/kanban/domain/entities/kanban_card.dart';
import 'package:not_app/features/reminders/domain/entities/reminder.dart';
import 'package:url_launcher/url_launcher.dart';

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
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Kart cihazda kaydedildi.')));
  }

  Future<void> _addAttachment() async {
    final file = await ref.read(filePickerServiceProvider).pickSingleFile();
    if (file == null) return;
    await ref
        .read(attachmentsRepositoryProvider)
        .addFromFile(parentType: 'card', parentId: widget.cardId, source: file);
  }

  Future<void> _addReminder() async {
    final DateTime now = DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      initialDate: now,
    );
    if (date == null || !mounted) return;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null) return;
    final DateTime local = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (!local.isAfter(DateTime.now())) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hatırlatıcı saati gelecekte olmalıdır.'),
          ),
        );
      return;
    }
    final zone = ref.read(notificationServiceProvider).localTimeZoneId;
    await ref
        .read(remindersRepositoryProvider)
        .create(
          parentType: 'card',
          parentId: widget.cardId,
          title: _title.text.trim().isEmpty
              ? 'Kart hatırlatıcısı'
              : _title.text.trim(),
          body: _description.text.trim(),
          scheduledAtUtc: local.toUtc(),
          timeZoneId: zone,
        );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(kanbanRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kart ayrıntısı')),
      body: StreamBuilder<KanbanCard?>(
        stream: repo.watchCard(widget.cardId),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final card = snapshot.data;
          if (card == null)
            return const Center(child: Text('Kart bulunamadı.'));
          if (_loadedCardId != card.id) {
            _loadedCardId = card.id;
            _title.text = card.title;
            _description.text = card.description ?? '';
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: <Widget>[
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
                    onPressed: _addReminder,
                    icon: const Icon(Icons.notifications_none),
                    label: const Text('Hatırlatıcı'),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final bool ok =
                          await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Kart silinsin mi?'),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
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
                        await repo.deleteCard(card.id);
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Sil'),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text('Ekler', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              _AttachmentList(parentId: card.id),
              const SizedBox(height: 28),
              Text(
                'Hatırlatıcılar',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              _ReminderList(parentId: card.id),
            ],
          );
        },
      ),
    );
  }
}

class _AttachmentList extends ConsumerWidget {
  const _AttachmentList({required this.parentId});
  final String parentId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(attachmentsRepositoryProvider);
    return StreamBuilder<List<AttachmentEntity>>(
      stream: repo.watchForParent('card', parentId),
      builder: (context, snapshot) {
        final data = snapshot.data ?? const <AttachmentEntity>[];
        if (data.isEmpty) return const Text('Ek dosya yok.');
        return Column(
          children: data
              .map(
                (item) => ListTile(
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: Text(item.fileName),
                  subtitle: Text(
                    '${(item.sizeBytes / 1024).ceil()} KB · ${item.transferState}',
                  ),
                  onTap: () async {
                    final file = await repo.ensureLocal(item.id);
                    await launchUrl(Uri.file(file.path));
                  },
                  trailing: IconButton(
                    onPressed: () => repo.remove(item.id),
                    icon: const Icon(Icons.close),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ReminderList extends ConsumerWidget {
  const _ReminderList({required this.parentId});
  final String parentId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(remindersRepositoryProvider);
    return StreamBuilder<List<ReminderEntity>>(
      stream: repo.watchForParent('card', parentId),
      builder: (context, snapshot) {
        final data = snapshot.data ?? const <ReminderEntity>[];
        if (data.isEmpty) return const Text('Hatırlatıcı yok.');
        return Column(
          children: data
              .map(
                (item) => ListTile(
                  leading: const Icon(Icons.notifications_none),
                  title: Text(item.title),
                  subtitle: Text(
                    '${item.scheduledAtUtc.toLocal()} · ${item.schedulingStatus}',
                  ),
                  trailing: IconButton(
                    onPressed: () => repo.remove(item.id),
                    icon: const Icon(Icons.close),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}
