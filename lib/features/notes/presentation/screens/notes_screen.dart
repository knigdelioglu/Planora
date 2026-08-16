import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/app/router/app_router.dart';
import 'package:not_app/app/widgets/common_widgets.dart';
import 'package:not_app/features/notes/domain/entities/note.dart';
import 'package:not_app/features/notes/presentation/screens/note_editor_screen.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});
  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  NoteFilter _filter = NoteFilter.all;

  String _label(NoteFilter value) => switch (value) {
    NoteFilter.all => 'Tümü',
    NoteFilter.favorites => 'Favoriler',
    NoteFilter.recent => 'Son kullanılan',
    NoteFilter.trash => 'Çöp kutusu',
  };

  Future<void> _create() async {
    final String id = await ref.read(notesRepositoryProvider).createNote();
    if (!mounted) return;
    await AppRouter.push<void>(context, NoteEditorScreen(noteId: id));
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(notesRepositoryProvider);
    return Column(
      children: <Widget>[
        AppPageHeader(
          title: 'Notlar',
          subtitle:
              'Fikirlerinizi ve belgelerinizi çevrimdışı çalışacak şekilde saklayın.',
          actions: <Widget>[
            FilledButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: const Text('Yeni not'),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<NoteFilter>(
              segments: NoteFilter.values
                  .map(
                    (value) => ButtonSegment<NoteFilter>(
                      value: value,
                      label: Text(_label(value)),
                    ),
                  )
                  .toList(),
              selected: <NoteFilter>{_filter},
              onSelectionChanged: (value) =>
                  setState(() => _filter = value.first),
              showSelectedIcon: false,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<List<NoteEntity>>(
            stream: repository.watchNotes(_filter),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorState(message: snapshot.error.toString());
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final List<NoteEntity> notes = snapshot.requireData;
              if (notes.isEmpty) {
                return EmptyState(
                  icon: _filter == NoteFilter.trash
                      ? Icons.delete_outline
                      : Icons.note_add_outlined,
                  title: _filter == NoteFilter.trash
                      ? 'Çöp kutusu boş'
                      : 'Henüz not yok',
                  message: _filter == NoteFilter.trash
                      ? 'Sildiğiniz notlar burada görünür.'
                      : 'İlk notunuzu oluşturup yazmaya başlayın.',
                  action: _filter == NoteFilter.trash
                      ? null
                      : FilledButton(
                          onPressed: _create,
                          child: const Text('Not oluştur'),
                        ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                itemCount: notes.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final NoteEntity note = notes[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    leading: Icon(
                      note.isDeleted
                          ? Icons.delete_outline
                          : Icons.description_outlined,
                    ),
                    title: Text(
                      note.title.trim().isEmpty ? 'Başlıksız not' : note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      note.document.plainText.trim().isEmpty
                          ? 'İçerik yok'
                          : note.document.plainText.replaceAll('\n', ' '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: note.isDeleted
                        ? PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'restore') {
                                await repository.restore(note.id);
                              } else if (value == 'delete') {
                                final bool confirmed =
                                    await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text(
                                          'Kalıcı olarak silinsin mi?',
                                        ),
                                        content: const Text(
                                          'Bu işlem bu cihazdaki notu geri alınamayacak şekilde kaldırır ve buluta silme kaydı gönderir.',
                                        ),
                                        actions: <Widget>[
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Vazgeç'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Kalıcı sil'),
                                          ),
                                        ],
                                      ),
                                    ) ??
                                    false;
                                if (confirmed) {
                                  await repository.deletePermanently(note.id);
                                }
                              }
                            },
                            itemBuilder: (_) => const <PopupMenuEntry<String>>[
                              PopupMenuItem(
                                value: 'restore',
                                child: Text('Geri yükle'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Kalıcı sil'),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              IconButton(
                                tooltip: note.isFavorite
                                    ? 'Favoriden çıkar'
                                    : 'Favoriye ekle',
                                onPressed: () => repository.setFavorite(
                                  note.id,
                                  !note.isFavorite,
                                ),
                                icon: Icon(
                                  note.isFavorite
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                ),
                              ),
                              PopupMenuButton<String>(
                                tooltip: 'Not işlemleri',
                                onSelected: (value) async {
                                  if (value == 'trash') {
                                    await repository.trash(note.id);
                                  }
                                },
                                itemBuilder: (_) =>
                                    const <PopupMenuEntry<String>>[
                                      PopupMenuItem(
                                        value: 'trash',
                                        child: Text('Çöpe taşı'),
                                      ),
                                    ],
                              ),
                            ],
                          ),
                    onTap: note.isDeleted
                        ? null
                        : () async {
                            await repository.markOpened(note.id);
                            if (!context.mounted) return;
                            await AppRouter.push<void>(
                              context,
                              NoteEditorScreen(noteId: note.id),
                            );
                          },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
