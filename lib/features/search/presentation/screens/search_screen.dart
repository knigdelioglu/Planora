import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/app/router/app_router.dart';
import 'package:not_app/app/widgets/common_widgets.dart';
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

sealed class _SearchListItem {}

class _HeaderItem extends _SearchListItem {
  _HeaderItem({required this.type, required this.title});
  final String type;
  final String title;
}

class _ResultItem extends _SearchListItem {
  _ResultItem({required this.result, required this.flatIndex});
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

  @override
  void initState() {
    super.initState();
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _internalFocusNode = FocusNode(debugLabel: 'SearchScreenFocusNode');
      _focusNode = _internalFocusNode!;
    }
    _focusNode.onKeyEvent = _handleKeyEvent;
    _query.addListener(_changed);
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  @override
  void didUpdateWidget(SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      if (oldWidget.focusNode != null) {
        oldWidget.focusNode!.onKeyEvent = null;
      }
      if (widget.focusNode != null) {
        _internalFocusNode?.dispose();
        _internalFocusNode = null;
        _focusNode = widget.focusNode!;
      } else {
        _internalFocusNode = FocusNode(debugLabel: 'SearchScreenFocusNode');
        _focusNode = _internalFocusNode!;
      }
      _focusNode.onKeyEvent = _handleKeyEvent;
    }
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
    _debounce = Timer(const Duration(milliseconds: 180), _search);
  }

  Future<void> _search() async {
    final String value = _query.text.trim();
    if (value.isEmpty) {
      setState(() {
        _results = const <SearchResultEntity>[];
        _selectedIndex = -1;
      });
      return;
    }
    setState(() => _busy = true);
    final data = await ref.read(searchRepositoryProvider).search(value);
    if (mounted) {
      setState(() {
        _results = data;
        _selectedIndex = -1;
        _busy = false;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.removeListener(_changed);
    _query.dispose();
    if (widget.focusNode != null) {
      widget.focusNode!.onKeyEvent = null;
    }
    _internalFocusNode?.dispose();
    super.dispose();
  }

  List<SearchResultEntity> _buildFlatList() {
    final List<SearchResultEntity> notes = _results
        .where((r) => r.entityType == 'note')
        .toList(growable: false);
    final List<SearchResultEntity> cards = _results
        .where((r) => r.entityType == 'card')
        .toList(growable: false);
    final List<SearchResultEntity> boards = _results
        .where((r) => r.entityType == 'board')
        .toList(growable: false);
    final List<SearchResultEntity> others = _results
        .where(
          (r) =>
              r.entityType != 'note' &&
              r.entityType != 'card' &&
              r.entityType != 'board',
        )
        .toList(growable: false);

    return <SearchResultEntity>[...notes, ...cards, ...boards, ...others];
  }

  List<_SearchListItem> _buildDisplayList() {
    final List<SearchResultEntity> notes = _results
        .where((r) => r.entityType == 'note')
        .toList(growable: false);
    final List<SearchResultEntity> cards = _results
        .where((r) => r.entityType == 'card')
        .toList(growable: false);
    final List<SearchResultEntity> boards = _results
        .where((r) => r.entityType == 'board')
        .toList(growable: false);
    final List<SearchResultEntity> others = _results
        .where(
          (r) =>
              r.entityType != 'note' &&
              r.entityType != 'card' &&
              r.entityType != 'board',
        )
        .toList(growable: false);

    final List<_SearchListItem> list = <_SearchListItem>[];
    int flatIndex = 0;

    if (notes.isNotEmpty) {
      list.add(_HeaderItem(type: 'note', title: 'Notlar (${notes.length})'));
      for (final item in notes) {
        list.add(_ResultItem(result: item, flatIndex: flatIndex++));
      }
    }

    if (cards.isNotEmpty) {
      list.add(_HeaderItem(type: 'card', title: 'Kartlar (${cards.length})'));
      for (final item in cards) {
        list.add(_ResultItem(result: item, flatIndex: flatIndex++));
      }
    }

    if (boards.isNotEmpty) {
      list.add(_HeaderItem(type: 'board', title: 'Panolar (${boards.length})'));
      for (final item in boards) {
        list.add(_ResultItem(result: item, flatIndex: flatIndex++));
      }
    }

    if (others.isNotEmpty) {
      list.add(_HeaderItem(type: 'other', title: 'Diğer (${others.length})'));
      for (final item in others) {
        list.add(_ResultItem(result: item, flatIndex: flatIndex++));
      }
    }

    return list;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final flatList = _buildFlatList();

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (flatList.isNotEmpty) {
        setState(() {
          if (_selectedIndex < flatList.length - 1) {
            _selectedIndex++;
          } else {
            _selectedIndex = flatList.length - 1;
          }
        });
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (flatList.isNotEmpty) {
        setState(() {
          if (_selectedIndex > 0) {
            _selectedIndex--;
          } else {
            _selectedIndex = -1;
          }
        });
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (flatList.isNotEmpty) {
        if (_selectedIndex >= 0 && _selectedIndex < flatList.length) {
          _open(flatList[_selectedIndex]);
        } else {
          _open(flatList.first);
        }
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_query.text.isNotEmpty) {
        _query.clear();
        setState(() {
          _results = const <SearchResultEntity>[];
          _selectedIndex = -1;
        });
        return KeyEventResult.handled;
      } else {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        } else {
          _focusNode.unfocus();
          return KeyEventResult.handled;
        }
      }
    }

    return KeyEventResult.ignored;
  }

  void _open(SearchResultEntity result) {
    switch (result.entityType) {
      case 'note':
        AppRouter.push<void>(
          context,
          NoteEditorScreen(noteId: result.entityId),
        );
      case 'card':
        AppRouter.push<void>(
          context,
          CardDetailScreen(cardId: result.entityId),
        );
      case 'board':
        AppRouter.push<void>(
          context,
          KanbanBoardScreen(boardId: result.entityId),
        );
    }
  }

  void _focusAndSelectQuery() {
    _focusNode.requestFocus();
    _query.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _query.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<_SearchListItem> displayItems = _buildDisplayList();
    final List<SearchResultEntity> flatList = _buildFlatList();

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            _focusAndSelectQuery,
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _focusAndSelectQuery,
      },
      child: Focus(
        autofocus: widget.autofocus,
        child: Material(
          color: Colors.transparent,
          child: Column(
            children: <Widget>[
              const AppPageHeader(
                title: 'Arama',
                subtitle:
                    'Notlar, kartlar ve panolar arasında tamamen yerel arama.',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  key: const ValueKey('search_text_field'),
                  controller: _query,
                  focusNode: _focusNode,
                  autofocus: widget.autofocus,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Ara… (⌘K)',
                    suffixIcon: _busy
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _query.text.isNotEmpty
                        ? IconButton(
                            key: const ValueKey('search_clear_button'),
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _query.clear();
                              setState(() {
                                _results = const <SearchResultEntity>[];
                                _selectedIndex = -1;
                              });
                            },
                          )
                        : null,
                  ),
                  onSubmitted: (_) {
                    if (flatList.isNotEmpty) {
                      if (_selectedIndex >= 0 &&
                          _selectedIndex < flatList.length) {
                        _open(flatList[_selectedIndex]);
                      } else {
                        _open(flatList.first);
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _query.text.trim().isEmpty
                    ? const EmptyState(
                        icon: Icons.search_rounded,
                        title: 'Ne arıyorsunuz?',
                        message:
                            'Not başlığı/içeriği, kart açıklaması veya pano adı yazın.',
                      )
                    : _results.isEmpty && !_busy
                    ? const EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'Sonuç bulunamadı',
                        message: 'Farklı bir kelime deneyin.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                        itemCount: displayItems.length,
                        itemBuilder: (context, index) {
                          final item = displayItems[index];
                          if (item is _HeaderItem) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                              child: Text(
                                item.title,
                                key: ValueKey('search_section_${item.type}'),
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                              ),
                            );
                          } else if (item is _ResultItem) {
                            final result = item.result;
                            final isSelected = item.flatIndex == _selectedIndex;
                            final icon = switch (result.entityType) {
                              'note' => Icons.description_outlined,
                              'card' => Icons.view_agenda_outlined,
                              'board' => Icons.view_kanban_outlined,
                              _ => Icons.search_rounded,
                            };
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 2.0,
                              ),
                              child: Material(
                                type: MaterialType.transparency,
                                child: ListTile(
                                  key: ValueKey(
                                    'search_result_${result.entityType}_${result.entityId}',
                                  ),
                                  selected: isSelected,
                                  selectedTileColor: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                      .withValues(alpha: 0.35),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  leading: Icon(icon),
                                  title: Text(
                                    result.title.isEmpty
                                        ? 'Başlıksız'
                                        : result.title,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  subtitle:
                                      (result.preview.isNotEmpty &&
                                          result.preview.trim() !=
                                              result.title.trim())
                                      ? Text(
                                          result.preview,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        )
                                      : null,
                                  trailing: isSelected
                                      ? const Icon(
                                          Icons.keyboard_return,
                                          size: 16,
                                        )
                                      : null,
                                  onTap: () {
                                    setState(
                                      () => _selectedIndex = item.flatIndex,
                                    );
                                    _open(result);
                                  },
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
