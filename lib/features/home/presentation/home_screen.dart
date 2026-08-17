import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/app/router/app_router.dart';
import 'package:not_app/app/theme/app_theme.dart';
import 'package:not_app/app/widgets/content/app_content.dart';
import 'package:not_app/app/widgets/navigation/app_toolbar.dart';
import 'package:not_app/features/kanban/domain/entities/board.dart';
import 'package:not_app/features/kanban/presentation/screens/kanban_board_screen.dart';
import 'package:not_app/features/kanban/presentation/widgets/kanban_color.dart';
import 'package:not_app/features/notes/domain/entities/note.dart';
import 'package:not_app/features/notes/domain/entities/note_document.dart';
import 'package:not_app/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:not_app/features/reminders/domain/entities/reminder.dart';
import 'package:uuid/uuid.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _capture = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _capture.dispose();
    super.dispose();
  }

  Future<void> _quickNote({bool openAfterCreate = false}) async {
    final String text = _capture.text.trim();
    if (text.isEmpty || _creating) return;
    setState(() => _creating = true);
    try {
      final repo = ref.read(notesRepositoryProvider);
      final String id = await repo.createNote();
      await repo.saveDocument(
        id,
        NoteDocument(
          version: NoteDocument.currentVersion,
          blocks: <NoteBlock>[
            NoteBlock(
              id: const Uuid().v7(),
              type: NoteBlockType.paragraph,
              text: text,
            ),
          ],
        ),
      );
      _capture.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Not oluşturuldu.'),
          action: SnackBarAction(
            label: 'Aç',
            onPressed: () =>
                AppRouter.push<void>(context, NoteEditorScreen(noteId: id)),
          ),
        ),
      );
      if (openAfterCreate && mounted) {
        await AppRouter.push<void>(context, NoteEditorScreen(noteId: id));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _newEmptyNote() async {
    final String id = await ref.read(notesRepositoryProvider).createNote();
    if (!mounted) return;
    await AppRouter.push<void>(context, NoteEditorScreen(noteId: id));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        AppToolbar(
          title: 'Ana Sayfa',
          actions: <Widget>[
            FilledButton.icon(
              onPressed: _newEmptyNote,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Yeni not'),
            ),
          ],
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool wide = constraints.maxWidth >= 900;
              final double horizontal = constraints.maxWidth < 600 ? 16 : 24;
              return ListView(
                padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 36),
                children: <Widget>[
                  _QuickCapture(
                    controller: _capture,
                    busy: _creating,
                    onSubmit: () => _quickNote(),
                  ),
                  const SizedBox(height: 28),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          flex: 3,
                          child: _RecentNotes(
                            stream: ref
                                .watch(notesRepositoryProvider)
                                .watchNotes(NoteFilter.recent),
                          ),
                        ),
                        const SizedBox(width: 32),
                        Expanded(
                          flex: 2,
                          child: _TodayReminders(
                            stream: ref
                                .watch(remindersRepositoryProvider)
                                .watchUpcoming(),
                          ),
                        ),
                      ],
                    )
                  else ...<Widget>[
                    _RecentNotes(
                      stream: ref
                          .watch(notesRepositoryProvider)
                          .watchNotes(NoteFilter.recent),
                    ),
                    const SizedBox(height: 28),
                    _TodayReminders(
                      stream: ref
                          .watch(remindersRepositoryProvider)
                          .watchUpcoming(),
                    ),
                  ],
                  const SizedBox(height: 30),
                  _RecentBoards(
                    stream: ref.watch(kanbanRepositoryProvider).watchBoards(),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _QuickCapture extends StatelessWidget {
  const _QuickCapture({
    required this.controller,
    required this.busy,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 860),
    child: TextField(
      controller: controller,
      minLines: 1,
      maxLines: 3,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => onSubmit(),
      decoration: InputDecoration(
        hintText: 'Bir fikir, görev veya not yaz…',
        prefixIcon: const Icon(Icons.edit_note_rounded, size: 21),
        suffixIcon: busy
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton(
                tooltip: 'Not oluştur',
                onPressed: onSubmit,
                icon: const Icon(Icons.arrow_upward_rounded, size: 19),
              ),
      ),
    ),
  );
}

class _RecentNotes extends ConsumerWidget {
  const _RecentNotes({required this.stream});

  final Stream<List<NoteEntity>> stream;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      const AppSectionHeader(title: 'Son notlar'),
      StreamBuilder<List<NoteEntity>>(
        stream: stream,
        builder: (context, snapshot) {
          final List<NoteEntity> data = snapshot.data ?? const <NoteEntity>[];
          if (data.isEmpty) {
            return Text(
              'Henüz not yok. Yukarıdaki alana yazarak ilk notunu oluşturabilirsin.',
              style: Theme.of(context).textTheme.bodySmall,
            );
          }
          return Column(
            children: data
                .take(5)
                .map((note) {
                  final String preview = note.document.plainText.trim();
                  return AppListRow(
                    leading: const Icon(Icons.description_outlined, size: 19),
                    title: Text(
                      note.title.trim().isEmpty ? 'Başlıksız not' : note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: preview.isEmpty
                        ? null
                        : Text(
                            preview.replaceAll('\n', ' '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    onTap: () async {
                      await ref
                          .read(notesRepositoryProvider)
                          .markOpened(note.id);
                      if (!context.mounted) return;
                      await AppRouter.push<void>(
                        context,
                        NoteEditorScreen(noteId: note.id),
                      );
                    },
                  );
                })
                .toList(growable: false),
          );
        },
      ),
    ],
  );
}

class _TodayReminders extends StatelessWidget {
  const _TodayReminders({required this.stream});

  final Stream<List<ReminderEntity>> stream;

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      const AppSectionHeader(title: 'Bugün'),
      StreamBuilder<List<ReminderEntity>>(
        stream: stream,
        builder: (context, snapshot) {
          final DateTime now = DateTime.now();
          final List<ReminderEntity> today =
              (snapshot.data ?? const <ReminderEntity>[])
                  .where((item) => _sameDay(item.scheduledAtUtc.toLocal(), now))
                  .take(5)
                  .toList(growable: false);
          if (today.isEmpty) {
            return Text(
              'Bugün için yaklaşan hatırlatıcı yok.',
              style: Theme.of(context).textTheme.bodySmall,
            );
          }
          return Column(
            children: today
                .map((item) {
                  final DateTime local = item.scheduledAtUtc.toLocal();
                  final String time = TimeOfDay.fromDateTime(
                    local,
                  ).format(context);
                  return AppListRow(
                    leading: SizedBox(
                      width: 46,
                      child: Text(
                        time,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    title: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                })
                .toList(growable: false),
          );
        },
      ),
    ],
  );
}

class _RecentBoards extends StatelessWidget {
  const _RecentBoards({required this.stream});

  final Stream<List<BoardEntity>> stream;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      const AppSectionHeader(title: 'Panolar'),
      StreamBuilder<List<BoardEntity>>(
        stream: stream,
        builder: (context, snapshot) {
          final List<BoardEntity> data = snapshot.data ?? const <BoardEntity>[];
          if (data.isEmpty) {
            return Text(
              'Henüz pano yok.',
              style: Theme.of(context).textTheme.bodySmall,
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final double cardWidth = constraints.maxWidth < 680
                  ? constraints.maxWidth
                  : 260;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: data
                    .take(6)
                    .map((board) {
                      final Color? accent = colorFromHex(board.colorHex);
                      return SizedBox(
                        width: cardWidth,
                        child: Material(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(
                            AppRadius.surface,
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(
                              AppRadius.surface,
                            ),
                            onTap: () => AppRouter.push<void>(
                              context,
                              KanbanBoardScreen(boardId: board.id),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: <Widget>[
                                  AppEntityColorIndicator(
                                    color: accent,
                                    vertical: true,
                                  ),
                                  const SizedBox(width: 11),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          board.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Son değişiklik ${MaterialLocalizations.of(context).formatShortDate(board.updatedAt.toLocal())}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
              );
            },
          );
        },
      ),
    ],
  );
}
