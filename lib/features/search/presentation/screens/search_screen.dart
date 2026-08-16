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
    if (value.isEmpty) {
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

  Future<void> _search() async {
    final String value = _query.text.trim();
    if (value.isEmpty) return;
    setState(() => _busy = true);
    final List<SearchResultEntity> data =
        await ref.read(searchRepositoryProvider).search(value);
    if (!mounted || value != _query.text.trim()) return;
    setState(() {
      _results = data;
      _selectedIndex = -1;
      _busy = false;
    });
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
  }

  @override
  Widget build(BuildContext context) {
    final List<SearchResultEntity> visible = _visibleResults;
    final List<_DisplayItem> display = _displayItems;
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
      child: Column(
        children: <Widget>[
          const AppToolbar(title: 'Arama'),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double horizontal = constraints.maxWidth < 600 ? 16 : 24;
                return Column(
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal, 0),
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
                                  visible[
                                      _selectedIndex < 0 ? 0 : _selectedIndex],
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(horizontal, 10, horizontal, 0),
                      child: Align(
                        alignment: Alignment.center,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: Wrap(
                            spacing: 7,
                            runSpacing: 7,
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
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _query.text.trim().isEmpty
                          ? const EmptyState(
                              icon: Icons.search_rounded,
                              title: 'Ne arıyorsunuz?',
                              message:
                                  'Notlar, kartlar ve panolar cihazınızda aranır.',
                            )
                          : visible.isEmpty && !_busy
                              ? const EmptyState(
                                  icon: Icons.search_off_rounded,
                                  title: 'Sonuç bulunamadı',
                                  message: 'Farklı bir kelime deneyin.',
                                )
                              : Center(
                                  child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 800),
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
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelLarge,
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
                                          subtitle: result.preview.trim().isEmpty ||
                                                  result.preview.trim() ==
                                                      result.title.trim()
                                              ? Text(
                                                  _typeLabel(
                                                    result.entityType,
                                                  ),
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
    );
  }
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
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.14),
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
