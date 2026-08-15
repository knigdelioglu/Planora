import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/app/router/app_router.dart';
import 'package:not_app/app/widgets/common_widgets.dart';
import 'package:not_app/features/kanban/domain/entities/board.dart';
import 'package:not_app/features/kanban/presentation/screens/kanban_board_screen.dart';
import 'package:not_app/features/notes/domain/entities/note.dart';
import 'package:not_app/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:not_app/features/reminders/domain/entities/reminder.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _quickNote(BuildContext context, WidgetRef ref) async {
    final String id = await ref.read(notesRepositoryProvider).createNote();
    if (context.mounted) {
      await AppRouter.push<void>(context, NoteEditorScreen(noteId: id));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: <Widget>[
        AppPageHeader(
          title: 'Ana Sayfa',
          subtitle: 'Bugün üzerinde çalıştığınız şeylere hızlıca dönün.',
          actions: <Widget>[
            FilledButton.icon(
              onPressed: () => _quickNote(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Hızlı not'),
            ),
          ],
        ),
        _Section<NoteEntity>(
          title: 'Son notlar',
          stream: ref
              .watch(notesRepositoryProvider)
              .watchNotes(NoteFilter.recent),
          empty: 'Henüz not yok.',
          itemBuilder: (note) => ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(note.title.isEmpty ? 'Başlıksız not' : note.title),
            subtitle: Text(
              note.document.plainText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => AppRouter.push<void>(
              context,
              NoteEditorScreen(noteId: note.id),
            ),
          ),
        ),
        _Section<ReminderEntity>(
          title: 'Yaklaşan hatırlatıcılar',
          stream: ref.watch(remindersRepositoryProvider).watchUpcoming(),
          empty: 'Yaklaşan hatırlatıcı yok.',
          itemBuilder: (item) => ListTile(
            leading: const Icon(Icons.notifications_none),
            title: Text(item.title),
            subtitle: Text('${item.scheduledAtUtc.toLocal()}'),
          ),
        ),
        _Section<BoardEntity>(
          title: 'Son panolar',
          stream: ref.watch(kanbanRepositoryProvider).watchBoards(),
          empty: 'Henüz pano yok.',
          itemBuilder: (board) => ListTile(
            leading: const Icon(Icons.view_kanban_outlined),
            title: Text(board.title),
            onTap: () => AppRouter.push<void>(
              context,
              KanbanBoardScreen(boardId: board.id),
            ),
          ),
        ),
      ],
    );
  }
}

class _Section<T> extends StatelessWidget {
  const _Section({
    required this.title,
    required this.stream,
    required this.empty,
    required this.itemBuilder,
  });

  final String title;
  final Stream<List<T>> stream;
  final String empty;
  final Widget Function(T value) itemBuilder;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
    child: SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          StreamBuilder<List<T>>(
            stream: stream,
            builder: (context, snapshot) {
              final List<T> data = snapshot.data ?? <T>[];
              if (data.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(empty),
                );
              }
              return Column(
                children: data.take(5).map(itemBuilder).toList(growable: false),
              );
            },
          ),
        ],
      ),
    ),
  );
}
