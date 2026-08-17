import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/app/router/app_router.dart';
import 'package:not_app/features/notes/domain/entities/linked_note.dart';
import 'package:not_app/features/notes/presentation/screens/note_editor_screen.dart';

class LinkedNotesSection extends ConsumerStatefulWidget {
  const LinkedNotesSection({super.key, required this.cardId});

  final String cardId;

  @override
  ConsumerState<LinkedNotesSection> createState() => _LinkedNotesSectionState();
}

class _LinkedNotesSectionState extends ConsumerState<LinkedNotesSection> {
  late Future<List<LinkedNoteEntity>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant LinkedNotesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cardId != widget.cardId) _reload();
  }

  void _reload() {
    _future = ref.read(noteKanbanRepositoryProvider).linkedNotesForCard(widget.cardId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LinkedNoteEntity>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          );
        }
        if (snapshot.hasError) return Text(snapshot.error.toString());
        final List<LinkedNoteEntity> notes =
            snapshot.data ?? const <LinkedNoteEntity>[];
        if (notes.isEmpty) {
          return const Text('Bu karta bağlı not yok.');
        }
        return Column(
          children: notes
              .map(
                (note) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined, size: 19),
                  title: Text(
                    note.title.trim().isEmpty ? 'Başlıksız not' : note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                  onTap: () => AppRouter.push<void>(
                    context,
                    NoteEditorScreen(noteId: note.noteId),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}
