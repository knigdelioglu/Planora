import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/app/router/app_router.dart';
import 'package:not_app/app/widgets/common_widgets.dart';
import 'package:not_app/app/widgets/content/app_content.dart';
import 'package:not_app/app/widgets/navigation/app_toolbar.dart';
import 'package:not_app/features/kanban/presentation/widgets/kanban_color.dart';
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
    NoteFilter.all => 'Tüm notlar',
    NoteFilter.favorites => 'Favoriler',
    NoteFilter.recent => 'Son kullanılan',
    NoteFilter.trash => 'Çöp kutusu',
  };

  IconData _filterIcon(NoteFilter value) => switch (value) {
    NoteFilter.all => Icons.notes_rounded,
    NoteFilter.favorites => Icons.star_outline_rounded,
    NoteFilter.recent => Icons.history_rounded,
    NoteFilter.trash => Icons.delete_outline_rounded,
  };

  Future<void> _create() async {
    final String id = await ref.read(notesRepositoryProvider).createNote();
    if (!mounted) return;
    await AppRouter.push<void>(context, NoteEditorScreen(noteId: id));
  }

  Future<void> _changeColor(NoteEntity note) async {
    final settings = ref.read(settingsRepositoryProvider);
    final String? current = await settings.watchEntityColor('note', note.id).first;
    if (!mounted) return;
    final ColorPickerValue? value = await showEntityColorDialog(
      context,
      dialogTitle: 'Not rengini değiştir',
      initialColorHex: current,
    );
    if (value == null) return;
    await settings.setEntityColor('note', note.id, value.colorHex);
  }

  Future<void> _trash(NoteEntity note) async {
    final repository = ref.read(notesRepositoryProvider);
    await repository.trash(note.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Not çöp kutusuna taşındı.'),
        action: SnackBarAction(
          label: 'Geri al',
          onPressed: () => repository.restore(note.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(notesRepositoryProvider);
    final settings = ref.watch(settingsRepositoryProvider);
    return Column(
      children: <Widget>[
        AppToolbar(
          title: 'Notlar',
          status: _filter == NoteFilter.all
              ? null
              : Text(_label(_filter), style: Theme.of(context).textTheme.bodySmall),
          actions: <Widget>[
            PopupMenuButton<NoteFilter>(
              tooltip: 'Not filtresi',
              initialValue: _filter,
              onSelected: (value) => setState(() => _filter = value),
              itemBuilder: (_) => NoteFilter.values
                  .map(
                    (value) => PopupMenuItem<NoteFilter>(
                      value: value,
                      child: Row(
                        children: <Widget>[
                          Icon(_filterIcon(value), size: 18),
                          const SizedBox(width: 9),
                          Text(_label(value)),
                          if (_filter == value) ...<Widget>[
                            const Spacer(),
                            const Icon(Icons.check_rounded, size: 18),
                          ],
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
              icon: const Icon(Icons.filter_list_rounded),
            ),
            if (_filter != NoteFilter.trash)
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Yeni not'),
              ),
          ],
        ),
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
                      ? Icons.delete_outline_rounded
                      : Icons.note_add_outlined,
                  title: _filter == NoteFilter.trash
                      ? 'Çöp kutusu boş'
                      : _filter == NoteFilter.favorites
                      ? 'Favori not yok'
                      : 'Henüz not yok',
                  message: _filter == NoteFilter.trash
                      ? 'Sildiğiniz notlar burada görünür.'
                      : 'Fikirlerinizi, listelerinizi ve belgelerinizi burada tutabilirsiniz.',
                  action: _filter == NoteFilter.trash
                      ? null
                      : FilledButton(
                          onPressed: _create,
                          child: const Text('Yeni not oluştur'),
                        ),
                );
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  final double horizontal = constraints.maxWidth < 600 ? 12 : 24;
                  return ListView.builder(
                    padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 32),
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final NoteEntity note = notes[index];
                      return StreamBuilder<String?>(
                        stream: settings.watchEntityColor('note', note.id),
                        builder: (context, colorSnapshot) {
                          final Color? accent = colorFromHex(colorSnapshot.data);
                          final String preview = note.document.plainText.trim();
                          return AppListRow(
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                AppEntityColorIndicator(color: accent),
                                const SizedBox(width: 9),
                                Icon(
                                  note.isDeleted
                                      ? Icons.delete_outline_rounded
                                      : Icons.description_outlined,
                                  size: 19,
                                ),
                              ],
                            ),
                            title: Text(
                              note.title.trim().isEmpty
                                  ? 'Başlıksız not'
                                  : note.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              preview.isEmpty
                                  ? 'İçerik yok'
                                  : preview.replaceAll('\n', ' '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: note.isDeleted
                                ? PopupMenuButton<String>(
                                    tooltip: 'Çöp kutusu işlemleri',
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
                                                  'Bu not geri alınamayacak şekilde silinecek.',
                                                ),
                                                actions: <Widget>[
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(
                                                      context,
                                                      false,
                                                    ),
                                                    child: const Text('Vazgeç'),
                                                  ),
                                                  FilledButton(
                                                    onPressed: () => Navigator.pop(
                                                      context,
                                                      true,
                                                    ),
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
                                    itemBuilder: (_) =>
                                        const <PopupMenuEntry<String>>[
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
                                      if (note.isFavorite)
                                        IconButton(
                                          tooltip: 'Favoriden çıkar',
                                          onPressed: () => repository.setFavorite(
                                            note.id,
                                            false,
                                          ),
                                          icon: const Icon(
                                            Icons.star_rounded,
                                            size: 19,
                                          ),
                                        ),
                                      PopupMenuButton<String>(
                                        tooltip: 'Not işlemleri',
                                        onSelected: (value) async {
                                          if (value == 'favorite') {
                                            await repository.setFavorite(
                                              note.id,
                                              !note.isFavorite,
                                            );
                                          } else if (value == 'color') {
                                            await _changeColor(note);
                                          } else if (value == 'trash') {
                                            await _trash(note);
                                          }
                                        },
                                        itemBuilder: (_) =>
                                            <PopupMenuEntry<String>>[
                                              PopupMenuItem(
                                                value: 'favorite',
                                                child: Text(
                                                  note.isFavorite
                                                      ? 'Favoriden çıkar'
                                                      : 'Favoriye ekle',
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'color',
                                                child: Text('Rengi değiştir'),
                                              ),
                                              const PopupMenuDivider(),
                                              const PopupMenuItem(
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
