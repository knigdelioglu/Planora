import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/app/router/app_router.dart';
import 'package:not_app/app/widgets/common_widgets.dart' show EmptyState;
import 'package:not_app/app/widgets/content/app_content.dart';
import 'package:not_app/app/widgets/inputs/app_search_field.dart';
import 'package:not_app/app/widgets/navigation/app_toolbar.dart';
import 'package:not_app/features/kanban/presentation/screens/card_detail_screen.dart';
import 'package:not_app/features/kanban/presentation/screens/kanban_board_screen.dart';
import 'package:not_app/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:not_app/features/search/domain/entities/search_result.dart';
import 'package:not_app/features/smart_views/public/smart_views_api.dart';
import 'package:not_app/features/tags/public/tags_api.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.autofocus = false, this.focusNode});

  final bool autofocus;
  final FocusNode? focusNode;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

sealed class _DisplayItem {}

class _SectionItem extends _DisplayItem {
  _SectionItem(this.type, this.label, this.count);

  final String type;
  final String label;
  final int count;
}

class _ResultItem extends _DisplayItem {
  _ResultItem(this.result, this.flatIndex);

  final SearchResultEntity result;
  final int flatIndex;
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _query = TextEditingController();
  FocusNode? _internalFocusNode;
  late FocusNode _focusNode;
  Timer? _debounce;
  List<SearchResultEntity> _results = const <SearchResultEntity>[];
  int _selectedIndex = -1;
  bool _busy = false;
  String _type = 'all';
  Set<String> _tagIds = <String>{};
  bool? _hasTags;
  bool? _hasReminder;
  bool? _hasAttachment;
  int? _updatedWithinDays;

  bool get _hasAdvancedFilters =>
      _tagIds.isNotEmpty ||
      _hasTags != null ||
      _hasReminder != null ||
      _hasAttachment != null ||
      _updatedWithinDays != null;

  int get _filterCount {
    int count = _tagIds.isNotEmpty ? 1 : 0;
    if (_hasTags != null) count++;
    if (_hasReminder != null) count++;
    if (_hasAttachment != null) count++;
    if (_updatedWithinDays != null) count++;
    return count;
  }

  FocusNode _resolveFocusNode(FocusNode? external) {
    if (external != null) return external;
    final FocusNode internal = FocusNode(debugLabel: 'SearchScreen');
    _internalFocusNode = internal;
    return internal;
  }

  @override
  void initState() {
    super.initState();
    _focusNode = _resolveFocusNode(widget.focusNode);
    _focusNode.onKeyEvent = _handleKeyEvent;
    _query.addListener(_changed);
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode) return;
    oldWidget.focusNode?.onKeyEvent = null;
    _internalFocusNode?.dispose();
    _internalFocusNode = null;
    _focusNode = _resolveFocusNode(widget.focusNode);
    _focusNode.onKeyEvent = _handleKeyEvent;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.removeListener(_changed);
    _query.dispose();
    widget.focusNode?.onKeyEvent = null;
    _internalFocusNode?.dispose();
    super.dispose();
  }

  List<SearchResultEntity> get _visibleResults {
    final List<SearchResultEntity> source = _type == 'all'
        ? _results
        : _results
              .where((item) => item.entityType == _type)
              .toList(growable: false);
    if (_type != 'all') return source;
    return <SearchResultEntity>[
      ...source.where((item) => item.entityType == 'note'),
      ...source.where((item) => item.entityType == 'card'),
      ...source.where((item) => item.entityType == 'board'),
      ...source.where(
        (item) =>
            item.entityType != 'note' &&
            item.entityType != 'card' &&
            item.entityType != 'board',
      ),
    ];
  }

  List<_DisplayItem> get _displayItems {
    final List<SearchResultEntity> visible = _visibleResults;
    if (_type != 'all') {
      return <_DisplayItem>[
        for (int i = 0; i < visible.length; i++) _ResultItem(visible[i], i),
      ];
    }

    final List<_DisplayItem> output = <_DisplayItem>[];
    int flatIndex = 0;
    void appendGroup(String type, String label) {
      final List<SearchResultEntity> group = visible
          .where((item) => item.entityType == type)
          .toList(growable: false);
      if (group.isEmpty) return;
      output.add(_SectionItem(type, label, group.length));
      for (final SearchResultEntity item in group) {
        output.add(_ResultItem(item, flatIndex++));
      }
    }

    appendGroup('note', 'Notlar');
    appendGroup('card', 'Kartlar');
    appendGroup('board', 'Panolar');
    final List<SearchResultEntity> others = visible
        .where(
          (item) =>
              item.entityType != 'note' &&
              item.entityType != 'card' &&
              item.entityType != 'board',
        )
        .toList(growable: false);
    if (others.isNotEmpty) {
      output.add(_SectionItem('other', 'Diğer', others.length));
      for (final SearchResultEntity item in others) {
        output.add(_ResultItem(item, flatIndex++));
      }
    }
    return output;
  }

  void _changed() {
    _debounce?.cancel();
    final String value = _query.text.trim();
    if (value.isEmpty && !_hasAdvancedFilters) {
      setState(() {
        _results = const <SearchResultEntity>[];
        _selectedIndex = -1;
        _busy = false;
      });
      return;
    }
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 180), _search);
  }

  ContentScope get _contentScope => switch (_type) {
    'note' => ContentScope.notes,
    'card' => ContentScope.cards,
    _ => ContentScope.all,
  };

  Future<void> _search() async {
    final String value = _query.text.trim();
    if (value.isEmpty && !_hasAdvancedFilters) return;
    if (_type == 'board' && _hasAdvancedFilters) {
      if (mounted) {
        setState(() {
          _results = const <SearchResultEntity>[];
          _selectedIndex = -1;
          _busy = false;
        });
      }
      return;
    }

    setState(() => _busy = true);
    final List<SearchResultEntity> data;
    if (_hasAdvancedFilters) {
      final List<SmartViewResult> filtered = await ref
          .read(smartViewsRepositoryProvider)
          .query(
            ContentFilter(
              scope: _contentScope,
              textQuery: value.isEmpty ? null : value,
              allTagIds: _tagIds.toList(growable: false),
              hasTags: _hasTags,
              hasReminder: _hasReminder,
              hasAttachment: _hasAttachment,
              updatedWithinDays: _updatedWithinDays,
            ),
          );
      data = filtered
          .map(
            (SmartViewResult result) => SearchResultEntity(
              entityType: result.entityType,
              entityId: result.entityId,
              title: result.title,
              preview: result.preview,
            ),
          )
          .toList(growable: false);
    } else {
      data = await ref.read(searchRepositoryProvider).search(value);
    }

    if (!mounted || value != _query.text.trim()) return;
    setState(() {
      _results = data;
      _selectedIndex = -1;
      _busy = false;
    });
  }

  Future<void> _openFilters() async {
    if (_type == 'board') return;
    final List<TagEntity> tags = await ref
        .read(tagsRepositoryProvider)
        .watchTags()
        .first;
    if (!mounted) return;

    final Set<String> tagIds = Set<String>.from(_tagIds);
    bool? hasTags = _hasTags;
    bool? hasReminder = _hasReminder;
    bool? hasAttachment = _hasAttachment;
    int? updatedWithinDays = _updatedWithinDays;

    final bool? apply = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Arama filtreleri'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Etiketler',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  if (tags.isEmpty)
                    Text(
                      'Henüz etiket yok.',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: tags
                          .map((TagEntity tag) {
                            final bool selected = tagIds.contains(tag.id);
                            return FilterChip(
                              selected: selected,
                              label: Text('#${tag.name}'),
                              onSelected: (bool value) {
                                setDialogState(() {
                                  if (value) {
                                    tagIds.add(tag.id);
                                    hasTags = null;
                                  } else {
                                    tagIds.remove(tag.id);
                                  }
                                });
                              },
                            );
                          })
                          .toList(growable: false),
                    ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: hasTags == null
                        ? 'any'
                        : hasTags!
                        ? 'tagged'
                        : 'untagged',
                    decoration: const InputDecoration(
                      labelText: 'Etiket durumu',
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'any', child: Text('Fark etmez')),
                      DropdownMenuItem(
                        value: 'tagged',
                        child: Text('Etiketli'),
                      ),
                      DropdownMenuItem(
                        value: 'untagged',
                        child: Text('Etiketsiz'),
                      ),
                    ],
                    onChanged: (String? value) => setDialogState(() {
                      hasTags = switch (value) {
                        'tagged' => true,
                        'untagged' => false,
                        _ => null,
                      };
                      if (hasTags == false) tagIds.clear();
                    }),
                  ),
                  const SizedBox(height: 10),
                  _NullableFilterField(
                    label: 'Hatırlatıcı',
                    value: hasReminder,
                    onChanged: (value) =>
                        setDialogState(() => hasReminder = value),
                  ),
                  const SizedBox(height: 8),
                  _NullableFilterField(
                    label: 'Dosya eki',
                    value: hasAttachment,
                    onChanged: (value) =>
                        setDialogState(() => hasAttachment = value),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int?>(
                    initialValue: updatedWithinDays,
                    decoration: const InputDecoration(labelText: 'Güncellenme'),
                    items: const <DropdownMenuItem<int?>>[
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Tüm zamanlar'),
                      ),
                      DropdownMenuItem<int?>(
                        value: 1,
                        child: Text('Son 24 saat'),
                      ),
                      DropdownMenuItem<int?>(
                        value: 7,
                        child: Text('Son 7 gün'),
                      ),
                      DropdownMenuItem<int?>(
                        value: 30,
                        child: Text('Son 30 gün'),
                      ),
                      DropdownMenuItem<int?>(
                        value: 90,
                        child: Text('Son 90 gün'),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => updatedWithinDays = value),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                setDialogState(() {
                  tagIds.clear();
                  hasTags = null;
                  hasReminder = null;
                  hasAttachment = null;
                  updatedWithinDays = null;
                });
              },
              child: const Text('Temizle'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Uygula'),
            ),
          ],
        ),
      ),
    );
    if (apply != true) return;
    setState(() {
      _tagIds = tagIds;
      _hasTags = hasTags;
      _hasReminder = hasReminder;
      _hasAttachment = hasAttachment;
      _updatedWithinDays = updatedWithinDays;
    });
    await _search();
  }

  void _clearFilters() {
    setState(() {
      _tagIds.clear();
      _hasTags = null;
      _hasReminder = null;
      _hasAttachment = null;
      _updatedWithinDays = null;
    });
    if (_query.text.trim().isEmpty) {
      setState(() => _results = const <SearchResultEntity>[]);
    } else {
      unawaited(_search());
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final List<SearchResultEntity> data = _visibleResults;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown && data.isNotEmpty) {
      setState(() {
        if (_selectedIndex < data.length - 1) {
          _selectedIndex += 1;
        } else {
          _selectedIndex = data.length - 1;
        }
      });
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp && data.isNotEmpty) {
      setState(() {
        _selectedIndex = _selectedIndex > 0 ? _selectedIndex - 1 : -1;
      });
      return KeyEventResult.handled;
    }
    if ((event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
        data.isNotEmpty) {
      _open(data[_selectedIndex < 0 ? 0 : _selectedIndex]);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_query.text.isNotEmpty) {
        _query.clear();
      } else if (_hasAdvancedFilters) {
        _clearFilters();
      } else if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        _focusNode.unfocus();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _open(SearchResultEntity result) async {
    switch (result.entityType) {
      case 'note':
        await AppRouter.push<void>(
          context,
          NoteEditorScreen(noteId: result.entityId),
        );
        return;
      case 'card':
        await AppRouter.push<void>(
          context,
          CardDetailScreen(cardId: result.entityId),
        );
        return;
      case 'board':
        await AppRouter.push<void>(
          context,
          KanbanBoardScreen(boardId: result.entityId),
        );
        return;
      default:
        return;
    }
  }

  String _typeLabel(String type) => switch (type) {
    'note' => 'Not',
    'card' => 'Kart',
    'board' => 'Pano',
    _ => 'Sonuç',
  };

  IconData _typeIcon(String type) => switch (type) {
    'note' => Icons.description_outlined,
    'card' => Icons.view_agenda_outlined,
    'board' => Icons.view_kanban_outlined,
    _ => Icons.search_rounded,
  };

  void _selectType(String type) {
    setState(() {
      _type = type;
      _selectedIndex = -1;
    });
    if (_query.text.trim().isNotEmpty || _hasAdvancedFilters) {
      unawaited(_search());
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<SearchResultEntity> visible = _visibleResults;
    final List<_DisplayItem> display = _displayItems;
    final bool hasSearchIntent =
        _query.text.trim().isNotEmpty || _hasAdvancedFilters;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () {
          _focusNode.requestFocus();
          _query.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _query.text.length,
          );
        },
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
          _focusNode.requestFocus();
          _query.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _query.text.length,
          );
        },
      },
      child: Scaffold(
        body: Column(
          children: <Widget>[
            const AppToolbar(title: 'Arama'),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double horizontal = constraints.maxWidth < 600
                      ? 16
                      : 24;
                  return Column(
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontal,
                          18,
                          horizontal,
                          0,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: KeyedSubtree(
                            key: const ValueKey('search_text_field'),
                            child: AppSearchField(
                              controller: _query,
                              focusNode: _focusNode,
                              autofocus: widget.autofocus,
                              busy: _busy,
                              hintText: 'Not, kart veya pano ara…',
                              shortcutLabel: '⌘K',
                              onClear: () {
                                _query.clear();
                                setState(() {});
                              },
                              onSubmitted: (_) {
                                if (visible.isNotEmpty) {
                                  _open(
                                    visible[_selectedIndex < 0
                                        ? 0
                                        : _selectedIndex],
                                  );
                                } else if (_hasAdvancedFilters) {
                                  unawaited(_search());
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontal,
                          10,
                          horizontal,
                          0,
                        ),
                        child: Align(
                          alignment: Alignment.center,
                          heightFactor: 1,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 760),
                            child: Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: <Widget>[
                                _TypeChip(
                                  label: 'Tümü',
                                  selected: _type == 'all',
                                  onSelected: () => _selectType('all'),
                                ),
                                _TypeChip(
                                  label: 'Notlar',
                                  selected: _type == 'note',
                                  onSelected: () => _selectType('note'),
                                ),
                                _TypeChip(
                                  label: 'Kartlar',
                                  selected: _type == 'card',
                                  onSelected: () => _selectType('card'),
                                ),
                                _TypeChip(
                                  label: 'Panolar',
                                  selected: _type == 'board',
                                  onSelected: () => _selectType('board'),
                                ),
                                FilterChip(
                                  selected: _hasAdvancedFilters,
                                  avatar: const Icon(
                                    Icons.tune_rounded,
                                    size: 16,
                                  ),
                                  label: Text(
                                    _filterCount == 0
                                        ? 'Filtreler'
                                        : 'Filtreler ($_filterCount)',
                                  ),
                                  onSelected: _type == 'board'
                                      ? null
                                      : (_) => unawaited(_openFilters()),
                                ),
                                if (_hasAdvancedFilters)
                                  ActionChip(
                                    avatar: const Icon(
                                      Icons.close_rounded,
                                      size: 15,
                                    ),
                                    label: const Text('Filtreleri temizle'),
                                    onPressed: _clearFilters,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_type == 'board' && _hasAdvancedFilters)
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            horizontal,
                            8,
                            horizontal,
                            0,
                          ),
                          child: Text(
                            'Etiket ve içerik filtreleri panolara uygulanmaz.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: !hasSearchIntent
                            ? const EmptyState(
                                icon: Icons.search_rounded,
                                title: 'Ne arıyorsunuz?',
                                message:
                                    'Notlar, kartlar ve panolar cihazınızda aranır. Etiket ve metadata filtreleri not/kart sonuçlarına uygulanabilir.',
                              )
                            : visible.isEmpty && !_busy
                            ? EmptyState(
                                icon: Icons.search_off_rounded,
                                title: 'Sonuç bulunamadı',
                                message: _hasAdvancedFilters
                                    ? 'Arama kelimesini veya filtreleri değiştirin.'
                                    : 'Farklı bir kelime deneyin.',
                              )
                            : Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 800,
                                  ),
                                  child: ListView.builder(
                                    padding: EdgeInsets.fromLTRB(
                                      horizontal,
                                      4,
                                      horizontal,
                                      32,
                                    ),
                                    itemCount: display.length,
                                    itemBuilder: (context, index) {
                                      final _DisplayItem item = display[index];
                                      if (item is _SectionItem) {
                                        return Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            4,
                                            14,
                                            4,
                                            5,
                                          ),
                                          child: Text(
                                            '${item.label} (${item.count})',
                                            key: ValueKey(
                                              'search_section_${item.type}',
                                            ),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.labelLarge,
                                          ),
                                        );
                                      }
                                      final _ResultItem resultItem =
                                          item as _ResultItem;
                                      final SearchResultEntity result =
                                          resultItem.result;
                                      final bool selected =
                                          resultItem.flatIndex ==
                                          _selectedIndex;
                                      return AppListRow(
                                        key: ValueKey(
                                          'search_result_${result.entityType}_${result.entityId}',
                                        ),
                                        selected: selected,
                                        leading: Icon(
                                          _typeIcon(result.entityType),
                                          size: 19,
                                        ),
                                        title: _HighlightedText(
                                          text: result.title.trim().isEmpty
                                              ? 'Başlıksız'
                                              : result.title,
                                          query: _query.text.trim(),
                                          maxLines: 1,
                                          selected: selected,
                                        ),
                                        subtitle:
                                            result.preview.trim().isEmpty ||
                                                result.preview.trim() ==
                                                    result.title.trim()
                                            ? Text(
                                                _typeLabel(result.entityType),
                                              )
                                            : Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: <Widget>[
                                                  Text(
                                                    _typeLabel(
                                                      result.entityType,
                                                    ),
                                                  ),
                                                  _HighlightedText(
                                                    text: result.preview
                                                        .replaceAll('\n', ' '),
                                                    query: _query.text.trim(),
                                                    maxLines: 2,
                                                    small: true,
                                                  ),
                                                ],
                                              ),
                                        trailing: selected
                                            ? const Icon(
                                                Icons.keyboard_return_rounded,
                                                size: 16,
                                              )
                                            : null,
                                        onTap: () {
                                          setState(
                                            () => _selectedIndex =
                                                resultItem.flatIndex,
                                          );
                                          _open(result);
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NullableFilterField extends StatelessWidget {
  const _NullableFilterField({
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
        selected: <String>{
          value == null
              ? 'any'
              : value!
              ? 'yes'
              : 'no',
        },
        onSelectionChanged: (selection) {
          onChanged(switch (selection.first) {
            'yes' => true,
            'no' => false,
            _ => null,
          });
        },
      ),
    ],
  );
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    showCheckmark: false,
    onSelected: (_) => onSelected(),
  );
}

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.query,
    required this.maxLines,
    this.small = false,
    this.selected = false,
  });

  final String text;
  final String query;
  final int maxLines;
  final bool small;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final TextStyle? base = small
        ? Theme.of(context).textTheme.bodySmall
        : Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
    if (query.isEmpty) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: base,
      );
    }
    final String lower = text.toLowerCase();
    final String needle = query.toLowerCase();
    final int index = lower.indexOf(needle);
    if (index < 0 || index + query.length > text.length) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: base,
      );
    }
    return Text.rich(
      TextSpan(
        style: base,
        children: <InlineSpan>[
          TextSpan(text: text.substring(0, index)),
          TextSpan(
            text: text.substring(index, index + query.length),
            style: base?.copyWith(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.14),
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: text.substring(index + query.length)),
        ],
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
