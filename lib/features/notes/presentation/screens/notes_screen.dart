import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/app/router/app_router.dart';
import 'package:not_app/app/widgets/common_widgets.dart';
import 'package:not_app/app/widgets/content/app_content.dart';
import 'package:not_app/app/widgets/navigation/app_toolbar.dart';
import 'package:not_app/core/settings/app_settings_repository.dart';
import 'package:not_app/features/kanban/presentation/widgets/kanban_color.dart';
import 'package:not_app/features/notes/domain/entities/note.dart';
import 'package:not_app/features/notes/domain/repositories/notes_repository.dart';
import 'package:not_app/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:not_app/features/notes/presentation/widgets/note_grid_card.dart';
import 'package:not_app/features/notes/presentation/widgets/note_move_to_kanban_dialog.dart';
import 'package:not_app/features/smart_views/presentation/screens/smart_views_screen.dart';
import 'package:not_app/features/tags/domain/entities/tag.dart';
import 'package:not_app/features/tags/presentation/widgets/tag_strip.dart';

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

  Future<void> _open(NoteEntity note) async {
    final repository = ref.read(notesRepositoryProvider);
    await repository.markOpened(note.id);
    if (!mounted) return;
    await AppRouter.push<void>(context, NoteEditorScreen(noteId: note.id));
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

  Future<void> _moveToKanban(NoteEntity note) async {
    final bool moved = await showMoveNoteToKanbanDialog(context, note: note);
    if (!mounted || !moved) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Not panoya taşındı.')),
    );
  }

  Future<void> _trash(NoteEntity note) async {
    final repository = ref.read(notesRepositoryProvider);
    await repository.trash(note.id);
    if (!mounted) return;
    final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> feedback =
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Not çöp kutusuna taşındı.'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Geri al',
              onPressed: () => repository.restore(note.id),
            ),
          ),
        );
    unawaited(
      Future<void>.delayed(const Duration(seconds: 5), feedback.close),
    );
  }

  Widget _listView(
    List<NoteEntity> notes,
    double horizontal,
    NotesRepository repository,
    AppSettingsRepository settings,
  ) {
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
                note.title.trim().isEmpty ? 'Başlıksız not' : note.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: note.isDeleted
                  ? Text(
                      preview.isEmpty ? 'İçerik yok' : preview.replaceAll('\n', ' '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          preview.isEmpty ? 'İçerik yok' : preview.replaceAll('\n', ' '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        TagStrip(
                          targetType: TagTargetType.note,
                          targetId: note.id,
                          editable: false,
                          compact: true,
                          maxVisible: 3,
                        ),
                      ],
                    ),
              trailing: note.isDeleted
                  ? PopupMenuButton<String>(
                      tooltip: 'Çöp kutusu işlemleri',
                      onSelected: (value) async {
                        if (value == 'restore') {
                          await repository.restore(note.id);
                        } else if (value == 'delete') {
                          final bool confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Kalıcı olarak silinsin mi?'),
                                  content: const Text(
                                    'Bu not geri alınamayacak şekilde silinecek.',
                                  ),
                                  actions: <Widget>[
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Vazgeç'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(context, true),
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
                        PopupMenuItem(value: 'restore', child: Text('Geri yükle')),
                        PopupMenuItem(value: 'delete', child: Text('Kalıcı sil')),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (note.isFavorite)
                          IconButton(
                            tooltip: 'Favoriden çıkar',
                            onPressed: () => repository.setFavorite(note.id, false),
                            icon: const Icon(Icons.star_rounded, size: 19),
                          ),
                        PopupMenuButton<String>(
                          tooltip: 'Not işlemleri',
                          onSelected: (value) async {
                            if (value == 'favorite') {
                              await repository.setFavorite(note.id, !note.isFavorite);
                            } else if (value == 'tags') {
                              await showTagPicker(
                                context,
                                ref,
                                targetType: TagTargetType.note,
                                targetId: note.id,
                              );
                            } else if (value == 'color') {
                              await _changeColor(note);
                            } else if (value == 'move') {
                              await _moveToKanban(note);
                            } else if (value == 'trash') {
                              await _trash(note);
                            }
                          },
                          itemBuilder: (_) => <PopupMenuEntry<String>>[
                            PopupMenuItem(
                              value: 'favorite',
                              child: Text(
                                note.isFavorite ? 'Favoriden çıkar' : 'Favoriye ekle',
                              ),
                            ),
                            const PopupMenuItem(value: 'tags', child: Text('Etiketler')),
                            const PopupMenuItem(value: 'color', child: Text('Rengi değiştir')),
                            const PopupMenuItem(value: 'move', child: Text('Panoya taşı')),
                            const PopupMenuDivider(),
                            const PopupMenuItem(value: 'trash', child: Text('Çöpe taşı')),
                          ],
                        ),
                      ],
                    ),
              onTap: note.isDeleted ? null : () => unawaited(_open(note)),
            );
          },
        );
      },
    );
  }

  Widget _gridView(
    List<NoteEntity> notes,
    double horizontal,
    NotesRepository repository,
    AppSettingsRepository settings,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final int crossAxisCount = switch (width) {
          < 520 => 2,
          < 820 => 3,
          < 1200 => 4,
          _ => 5,
        };
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 32),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 226,
          ),
          itemCount: notes.length,
          itemBuilder: (context, index) {
            final NoteEntity note = notes[index];
            return StreamBuilder<String?>(
              stream: settings.watchEntityColor('note', note.id),
              builder: (context, colorSnapshot) {
                final Color? accent = colorFromHex(colorSnapshot.data);
                final String plain = note.document.plainText.trim();
                final String preview = plain.isEmpty
                    ? 'İçerik yok'
                    : plain.replaceAll('\n', ' ');
                return NoteGridCard(
                  title: note.title.trim().isEmpty ? 'Başlıksız not' : note.title,
                  preview: preview,
                  updatedAt: note.updatedAt,
                  isFavorite: note.isFavorite,
                  accent: accent,
                  onTap: () => unawaited(_open(note)),
                  onToggleFavorite: () => unawaited(
                    repository.setFavorite(note.id, !note.isFavorite),
                  ),
                  onChangeColor: () => unawaited(_changeColor(note)),
                  onMoveToKanban: () => unawaited(_moveToKanban(note)),
                  onTrash: () => unawaited(_trash(note)),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(notesRepositoryProvider);
    final settings = ref.watch(settingsRepositoryProvider);
    return StreamBuilder<NoteViewMode>(
      stream: settings.watchNotesViewMode(),
      initialData: NoteViewMode.list,
      builder: (context, viewSnapshot) {
        final NoteViewMode viewMode = viewSnapshot.data ?? NoteViewMode.list;
        return Column(
          children: <Widget>[
            AppToolbar(
              title: 'Notlar',
              status: _filter == NoteFilter.all
                  ? null
                  : Text(
                      _label(_filter),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
              actions: <Widget>[
                IconButton(
                  tooltip: 'Akıllı Görünümler',
                  onPressed: () => AppRouter.push<void>(
                    context,
                    const SmartViewsScreen(),
                  ),
                  icon: const Icon(Icons.auto_awesome_motion_outlined),
                ),
                if (_filter != NoteFilter.trash)
                  SegmentedButton<NoteViewMode>(
                    showSelectedIcon: false,
                    segments: const <ButtonSegment<NoteViewMode>>[
                      ButtonSegment(
                        value: NoteViewMode.list,
                        icon: Icon(Icons.view_list_rounded, size: 18),
                        tooltip: 'Liste görünümü',
                      ),
                      ButtonSegment(
                        value: NoteViewMode.grid,
                        icon: Icon(Icons.grid_view_rounded, size: 18),
                        tooltip: 'Kart görünümü',
                      ),
                    ],
                    selected: <NoteViewMode>{viewMode},
                    onSelectionChanged: (selection) {
                      if (selection.isNotEmpty) {
                        unawaited(settings.setNotesViewMode(selection.first));
                      }
                    },
                  ),
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
                      if (_filter == NoteFilter.trash || viewMode == NoteViewMode.list) {
                        return _listView(notes, horizontal, repository, settings);
                      }
                      return _gridView(notes, horizontal, repository, settings);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
