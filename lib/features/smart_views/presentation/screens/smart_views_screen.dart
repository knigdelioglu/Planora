import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/app/router/app_router.dart';
import 'package:not_app/app/widgets/common_widgets.dart';
import 'package:not_app/app/widgets/content/app_content.dart';
import 'package:not_app/app/widgets/navigation/app_toolbar.dart';
import 'package:not_app/features/kanban/presentation/screens/card_detail_screen.dart';
import 'package:not_app/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:not_app/features/smart_views/domain/entities/content_filter.dart';
import 'package:not_app/features/smart_views/domain/entities/smart_view.dart';
import 'package:not_app/features/smart_views/domain/entities/smart_view_result.dart';
import 'package:not_app/features/tags/domain/entities/tag.dart';
import 'package:not_app/features/tags/presentation/widgets/tag_strip.dart';

final class _ViewChoice {
  const _ViewChoice({
    required this.key,
    required this.name,
    required this.icon,
    required this.filter,
    this.saved,
  });

  final String key;
  final String name;
  final IconData icon;
  final ContentFilter filter;
  final SmartViewEntity? saved;
}

const List<_ViewChoice> _systemViews = <_ViewChoice>[
  _ViewChoice(
    key: 'favorites',
    name: 'Favoriler',
    icon: Icons.star_outline_rounded,
    filter: ContentFilter(scope: ContentScope.notes, favorite: true),
  ),
  _ViewChoice(
    key: 'untagged',
    name: 'Etiketsiz',
    icon: Icons.sell_outlined,
    filter: ContentFilter(hasTags: false),
  ),
  _ViewChoice(
    key: 'reminders',
    name: 'Hatırlatıcılı',
    icon: Icons.notifications_none_rounded,
    filter: ContentFilter(hasReminder: true),
  ),
  _ViewChoice(
    key: 'attachments',
    name: 'Dosyalı',
    icon: Icons.attach_file_rounded,
    filter: ContentFilter(hasAttachment: true),
  ),
  _ViewChoice(
    key: 'last7days',
    name: 'Son 7 Gün',
    icon: Icons.history_rounded,
    filter: ContentFilter(updatedWithinDays: 7),
  ),
];

class SmartViewsScreen extends ConsumerStatefulWidget {
  const SmartViewsScreen({super.key, this.initialViewId});

  final String? initialViewId;

  @override
  ConsumerState<SmartViewsScreen> createState() => _SmartViewsScreenState();
}

class _SmartViewsScreenState extends ConsumerState<SmartViewsScreen> {
  String _selectedKey = _systemViews.first.key;

  @override
  void initState() {
    super.initState();
    if (widget.initialViewId != null) {
      _selectedKey = 'saved:${widget.initialViewId}';
    }
  }

  Future<void> _createView() async {
    final _EditorResult? result = await showSmartViewEditor(context, ref);
    if (result == null) return;
    final String id = await ref.read(smartViewsRepositoryProvider).createView(
      name: result.name,
      filter: result.filter,
      iconKey: result.iconKey,
    );
    if (mounted) setState(() => _selectedKey = 'saved:$id');
  }

  Future<void> _editView(SmartViewEntity view) async {
    final _EditorResult? result = await showSmartViewEditor(
      context,
      ref,
      initial: view,
    );
    if (result == null) return;
    await ref.read(smartViewsRepositoryProvider).updateView(
      viewId: view.id,
      name: result.name,
      filter: result.filter,
      iconKey: result.iconKey,
    );
  }

  Future<void> _deleteView(SmartViewEntity view) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('“${view.name}” silinsin mi?'),
            content: const Text(
              'Yalnızca kayıtlı görünüm silinir; notlar, kartlar ve etiketler etkilenmez.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Sil'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await ref.read(smartViewsRepositoryProvider).deleteView(view.id);
    if (mounted && _selectedKey == 'saved:${view.id}') {
      setState(() => _selectedKey = _systemViews.first.key);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(smartViewsRepositoryProvider);
    return Scaffold(
      body: Column(
        children: <Widget>[
          AppToolbar(
            title: 'Akıllı Görünümler',
            leading: Navigator.of(context).canPop()
                ? IconButton(
                    tooltip: 'Geri',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  )
                : null,
            actions: <Widget>[
              FilledButton.icon(
                onPressed: _createView,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Yeni görünüm'),
              ),
            ],
          ),
          Expanded(
            child: StreamBuilder<List<SmartViewEntity>>(
              stream: repository.watchViews(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ErrorState(message: snapshot.error.toString());
                }
                final List<SmartViewEntity> saved =
                    snapshot.data ?? const <SmartViewEntity>[];
                final List<_ViewChoice> choices = <_ViewChoice>[
                  ..._systemViews,
                  ...saved.map(
                    (SmartViewEntity view) => _ViewChoice(
                      key: 'saved:${view.id}',
                      name: view.name,
                      icon: _iconFor(view.iconKey),
                      filter: view.filter,
                      saved: view,
                    ),
                  ),
                ];
                final _ViewChoice selected = choices.firstWhere(
                  (_ViewChoice choice) => choice.key == _selectedKey,
                  orElse: () => choices.first,
                );

                return LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 760) {
                      return Column(
                        children: <Widget>[
                          _CompactSelector(
                            selected: selected,
                            choices: choices,
                            onSelected: (choice) =>
                                setState(() => _selectedKey = choice.key),
                            onEdit: _editView,
                            onDelete: _deleteView,
                          ),
                          const Divider(height: 1),
                          Expanded(child: _Results(choice: selected)),
                        ],
                      );
                    }
                    return Row(
                      children: <Widget>[
                        SizedBox(
                          width: 250,
                          child: _ViewList(
                            selected: selected,
                            choices: choices,
                            onSelected: (choice) =>
                                setState(() => _selectedKey = choice.key),
                            onEdit: _editView,
                            onDelete: _deleteView,
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(child: _Results(choice: selected)),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewList extends StatelessWidget {
  const _ViewList({
    required this.selected,
    required this.choices,
    required this.onSelected,
    required this.onEdit,
    required this.onDelete,
  });

  final _ViewChoice selected;
  final List<_ViewChoice> choices;
  final ValueChanged<_ViewChoice> onSelected;
  final ValueChanged<SmartViewEntity> onEdit;
  final ValueChanged<SmartViewEntity> onDelete;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(10, 12, 10, 24),
    children: <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        child: Text('HAZIR', style: Theme.of(context).textTheme.labelSmall),
      ),
      ...choices.where((choice) => choice.saved == null).map(
        (choice) => _row(choice),
      ),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        child: Text('KAYITLI', style: Theme.of(context).textTheme.labelSmall),
      ),
      if (!choices.any((choice) => choice.saved != null))
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            'Henüz özel görünüm yok.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ...choices.where((choice) => choice.saved != null).map(
        (choice) => _row(choice),
      ),
    ],
  );

  Widget _row(_ViewChoice choice) => AppListRow(
    selected: selected.key == choice.key,
    leading: Icon(choice.icon, size: 19),
    title: Text(choice.name, maxLines: 1, overflow: TextOverflow.ellipsis),
    trailing: choice.saved == null
        ? null
        : PopupMenuButton<String>(
            tooltip: 'Görünüm işlemleri',
            onSelected: (value) {
              if (value == 'edit') onEdit(choice.saved!);
              if (value == 'delete') onDelete(choice.saved!);
            },
            itemBuilder: (_) => const <PopupMenuEntry<String>>[
              PopupMenuItem(value: 'edit', child: Text('Düzenle')),
              PopupMenuItem(value: 'delete', child: Text('Sil')),
            ],
          ),
    onTap: () => onSelected(choice),
  );
}

class _CompactSelector extends StatelessWidget {
  const _CompactSelector({
    required this.selected,
    required this.choices,
    required this.onSelected,
    required this.onEdit,
    required this.onDelete,
  });

  final _ViewChoice selected;
  final List<_ViewChoice> choices;
  final ValueChanged<_ViewChoice> onSelected;
  final ValueChanged<SmartViewEntity> onEdit;
  final ValueChanged<SmartViewEntity> onDelete;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
    child: Row(
      children: <Widget>[
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: selected.key,
            decoration: const InputDecoration(
              labelText: 'Görünüm',
              isDense: true,
            ),
            items: choices
                .map(
                  (choice) => DropdownMenuItem<String>(
                    value: choice.key,
                    child: Row(
                      children: <Widget>[
                        Icon(choice.icon, size: 17),
                        const SizedBox(width: 8),
                        Flexible(child: Text(choice.name)),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: (key) {
              if (key == null) return;
              onSelected(choices.firstWhere((choice) => choice.key == key));
            },
          ),
        ),
        if (selected.saved != null) ...<Widget>[
          const SizedBox(width: 6),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit(selected.saved!);
              if (value == 'delete') onDelete(selected.saved!);
            },
            itemBuilder: (_) => const <PopupMenuEntry<String>>[
              PopupMenuItem(value: 'edit', child: Text('Düzenle')),
              PopupMenuItem(value: 'delete', child: Text('Sil')),
            ],
          ),
        ],
      ],
    ),
  );
}

class _Results extends ConsumerWidget {
  const _Results({required this.choice});

  final _ViewChoice choice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(smartViewsRepositoryProvider);
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Row(
            children: <Widget>[
              Icon(choice.icon, size: 20),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  choice.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<SmartViewResult>>(
            stream: repository.watchResults(choice.filter),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorState(message: snapshot.error.toString());
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final List<SmartViewResult> results = snapshot.requireData;
              if (results.isEmpty) {
                return const EmptyState(
                  icon: Icons.filter_alt_off_outlined,
                  title: 'Eşleşen içerik yok',
                  message:
                      'Bu görünümün koşullarına uyan not veya kart bulunamadı.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 28),
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final SmartViewResult result = results[index];
                  return AppListRow(
                    leading: Icon(
                      result.entityType == 'note'
                          ? Icons.description_outlined
                          : Icons.view_kanban_outlined,
                      size: 19,
                    ),
                    title: Text(
                      result.title.trim().isEmpty
                          ? result.entityType == 'note'
                                ? 'Başlıksız not'
                                : 'Başlıksız kart'
                          : result.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      result.preview.trim().isEmpty
                          ? result.entityType == 'note'
                                ? 'İçerik yok'
                                : 'Açıklama yok'
                          : result.preview.replaceAll('\n', ' '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Wrap(
                      spacing: 6,
                      children: <Widget>[
                        if (result.isFavorite)
                          const Icon(Icons.star_rounded, size: 16),
                        if (result.hasReminder)
                          const Icon(Icons.notifications_none_rounded, size: 16),
                        if (result.hasAttachment)
                          const Icon(Icons.attach_file_rounded, size: 16),
                      ],
                    ),
                    onTap: () async {
                      if (result.entityType == 'note') {
                        await AppRouter.push<void>(
                          context,
                          NoteEditorScreen(noteId: result.entityId),
                        );
                      } else {
                        await AppRouter.push<void>(
                          context,
                          CardDetailScreen(cardId: result.entityId),
                        );
                      }
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

final class _EditorResult {
  const _EditorResult({
    required this.name,
    required this.iconKey,
    required this.filter,
  });

  final String name;
  final String iconKey;
  final ContentFilter filter;
}

Future<_EditorResult?> showSmartViewEditor(
  BuildContext context,
  WidgetRef ref, {
  SmartViewEntity? initial,
}) async {
  final TextEditingController name = TextEditingController(text: initial?.name);
  final TextEditingController textQuery = TextEditingController(
    text: initial?.filter.textQuery,
  );
  ContentScope scope = initial?.filter.scope ?? ContentScope.all;
  final Set<String> tagIds = Set<String>.from(
    initial?.filter.allTagIds ?? const <String>[],
  );
  bool? hasTags = initial?.filter.hasTags;
  bool? favorite = initial?.filter.favorite;
  bool? hasReminder = initial?.filter.hasReminder;
  bool? hasAttachment = initial?.filter.hasAttachment;
  int? days = initial?.filter.updatedWithinDays;
  ContentSortField sortField =
      initial?.filter.sortField ?? ContentSortField.updatedAt;
  ContentSortDirection sortDirection =
      initial?.filter.sortDirection ?? ContentSortDirection.descending;

  final List<TagEntity> availableTags = await ref
      .read(tagsRepositoryProvider)
      .watchTags()
      .first;
  if (!context.mounted) {
    name.dispose();
    textQuery.dispose();
    return null;
  }

  final _EditorResult? result = await showDialog<_EditorResult>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(
          initial == null ? 'Yeni Akıllı Görünüm' : 'Görünümü düzenle',
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Ad'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textQuery,
                  decoration: const InputDecoration(
                    labelText: 'Metin içerir',
                    hintText: 'İsteğe bağlı',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ContentScope>(
                  initialValue: scope,
                  decoration: const InputDecoration(labelText: 'İçerik'),
                  items: const <DropdownMenuItem<ContentScope>>[
                    DropdownMenuItem(
                      value: ContentScope.all,
                      child: Text('Notlar + Kartlar'),
                    ),
                    DropdownMenuItem(
                      value: ContentScope.notes,
                      child: Text('Yalnız Notlar'),
                    ),
                    DropdownMenuItem(
                      value: ContentScope.cards,
                      child: Text('Yalnız Kartlar'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => scope = value);
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Gerekli etiketler',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                if (availableTags.isEmpty)
                  Text(
                    'Henüz etiket yok.',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: availableTags.map((tag) {
                      final bool selected = tagIds.contains(tag.id);
                      final Color color = tagColor(context, tag.colorKey);
                      return FilterChip(
                        selected: selected,
                        avatar: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        label: Text('#${tag.name}'),
                        onSelected: (value) => setState(() {
                          if (value) {
                            tagIds.add(tag.id);
                            hasTags = null;
                          } else {
                            tagIds.remove(tag.id);
                          }
                        }),
                      );
                    }).toList(growable: false),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: hasTags == null
                      ? 'any'
                      : hasTags!
                      ? 'tagged'
                      : 'untagged',
                  decoration: const InputDecoration(labelText: 'Etiket durumu'),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'any', child: Text('Fark etmez')),
                    DropdownMenuItem(value: 'tagged', child: Text('Etiketli')),
                    DropdownMenuItem(value: 'untagged', child: Text('Etiketsiz')),
                  ],
                  onChanged: (value) => setState(() {
                    hasTags = switch (value) {
                      'tagged' => true,
                      'untagged' => false,
                      _ => null,
                    };
                    if (hasTags == false) tagIds.clear();
                  }),
                ),
                const SizedBox(height: 12),
                _NullableBoolField(
                  label: 'Favori',
                  value: favorite,
                  onChanged: (value) => setState(() => favorite = value),
                ),
                const SizedBox(height: 8),
                _NullableBoolField(
                  label: 'Hatırlatıcı',
                  value: hasReminder,
                  onChanged: (value) => setState(() => hasReminder = value),
                ),
                const SizedBox(height: 8),
                _NullableBoolField(
                  label: 'Dosya eki',
                  value: hasAttachment,
                  onChanged: (value) => setState(() => hasAttachment = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: days?.toString() ?? 'all',
                  decoration: const InputDecoration(labelText: 'Güncellenme'),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'all', child: Text('Tüm zamanlar')),
                    DropdownMenuItem(value: '1', child: Text('Son 24 saat')),
                    DropdownMenuItem(value: '7', child: Text('Son 7 gün')),
                    DropdownMenuItem(value: '30', child: Text('Son 30 gün')),
                    DropdownMenuItem(value: '90', child: Text('Son 90 gün')),
                  ],
                  onChanged: (value) => setState(() {
                    days = value == null || value == 'all'
                        ? null
                        : int.tryParse(value);
                  }),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: DropdownButtonFormField<ContentSortField>(
                        initialValue: sortField,
                        decoration: const InputDecoration(labelText: 'Sırala'),
                        items: const <DropdownMenuItem<ContentSortField>>[
                          DropdownMenuItem(
                            value: ContentSortField.updatedAt,
                            child: Text('Güncelleme'),
                          ),
                          DropdownMenuItem(
                            value: ContentSortField.title,
                            child: Text('Başlık'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => sortField = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<ContentSortDirection>(
                        initialValue: sortDirection,
                        decoration: const InputDecoration(labelText: 'Yön'),
                        items: const <DropdownMenuItem<ContentSortDirection>>[
                          DropdownMenuItem(
                            value: ContentSortDirection.descending,
                            child: Text('Azalan'),
                          ),
                          DropdownMenuItem(
                            value: ContentSortDirection.ascending,
                            child: Text('Artan'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => sortDirection = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () {
              final String cleanName = name.text.trim();
              if (cleanName.isEmpty) return;
              Navigator.pop(
                dialogContext,
                _EditorResult(
                  name: cleanName,
                  iconKey: initial?.iconKey ?? 'filter_alt',
                  filter: ContentFilter(
                    scope: scope,
                    textQuery: textQuery.text.trim().isEmpty
                        ? null
                        : textQuery.text.trim(),
                    allTagIds: tagIds.toList(growable: false),
                    hasTags: hasTags,
                    favorite: scope == ContentScope.cards ? null : favorite,
                    hasReminder: hasReminder,
                    hasAttachment: hasAttachment,
                    updatedWithinDays: days,
                    sortField: sortField,
                    sortDirection: sortDirection,
                  ),
                ),
              );
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  textQuery.dispose();
  return result;
}

class _NullableBoolField extends StatelessWidget {
  const _NullableBoolField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool? value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Expanded(child: Text(label)),
      SegmentedButton<String>(
        showSelectedIcon: false,
        segments: const <ButtonSegment<String>>[
          ButtonSegment(value: 'any', label: Text('Fark etmez')),
          ButtonSegment(value: 'yes', label: Text('Var')),
          ButtonSegment(value: 'no', label: Text('Yok')),
        ],
        selected: <String>{value == null ? 'any' : value! ? 'yes' : 'no'},
        onSelectionChanged: (selection) {
          final String selected = selection.first;
          onChanged(switch (selected) {
            'yes' => true,
            'no' => false,
            _ => null,
          });
        },
      ),
    ],
  );
}

IconData _iconFor(String key) => switch (key) {
  'star' => Icons.star_outline_rounded,
  'notifications' => Icons.notifications_none_rounded,
  'attachment' => Icons.attach_file_rounded,
  'history' => Icons.history_rounded,
  'tag' => Icons.sell_outlined,
  _ => Icons.filter_alt_outlined,
};
