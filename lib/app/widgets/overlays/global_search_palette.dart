import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/app/theme/app_theme.dart';
import 'package:not_app/app/widgets/inputs/app_search_field.dart';
import 'package:not_app/features/search/domain/entities/search_result.dart';

class GlobalSearchPalette extends ConsumerStatefulWidget {
  const GlobalSearchPalette({super.key});

  @override
  ConsumerState<GlobalSearchPalette> createState() => _GlobalSearchPaletteState();
}

class _GlobalSearchPaletteState extends ConsumerState<GlobalSearchPalette> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _focusNode = FocusNode(debugLabel: 'GlobalSearchPalette');
  Timer? _debounce;
  List<SearchResultEntity> _results = const <SearchResultEntity>[];
  int _selectedIndex = -1;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _focusNode.onKeyEvent = _handleKey;
    _query.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.removeListener(_onChanged);
    _query.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged() {
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
    _debounce = Timer(const Duration(milliseconds: 160), _search);
  }

  Future<void> _search() async {
    final String value = _query.text.trim();
    if (value.isEmpty) return;
    setState(() => _busy = true);
    try {
      final List<SearchResultEntity> results = await ref
          .read(searchRepositoryProvider)
          .search(value);
      if (!mounted || value != _query.text.trim()) return;
      setState(() {
        _results = results.take(12).toList(growable: false);
        _selectedIndex = results.isEmpty ? -1 : 0;
        _busy = false;
      });
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    if (_results.isEmpty) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1)
            .clamp(0, _results.length - 1)
            .toInt();
      });
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1)
            .clamp(0, _results.length - 1)
            .toInt();
      });
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final int index = _selectedIndex < 0 ? 0 : _selectedIndex;
      Navigator.of(context).pop(_results[index]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  IconData _icon(String type) => switch (type) {
        'note' => Icons.description_outlined,
        'card' => Icons.view_agenda_outlined,
        'board' => Icons.view_kanban_outlined,
        _ => Icons.search_rounded,
      };

  String _typeLabel(String type) => switch (type) {
        'note' => 'Not',
        'card' => 'Kart',
        'board' => 'Pano',
        _ => 'Sonuç',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      key: const ValueKey('global_search_palette'),
      alignment: const Alignment(0, -0.46),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 660, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AppSearchField(
                key: const ValueKey('global_search_text_field'),
                controller: _query,
                focusNode: _focusNode,
                autofocus: true,
                busy: _busy,
                hintText: 'Not, kart veya pano ara…',
                shortcutLabel: 'Esc',
                onClear: () => _query.clear(),
                onSubmitted: (_) {
                  if (_results.isNotEmpty) {
                    Navigator.of(context).pop(
                      _results[_selectedIndex < 0 ? 0 : _selectedIndex],
                    );
                  }
                },
              ),
              if (_query.text.trim().isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 24, 12, 18),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.keyboard_rounded,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Yazmaya başla · ↑↓ seç · Enter aç · Esc kapat',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                )
              else if (_results.isEmpty && !_busy)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'Sonuç bulunamadı',
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(top: 8),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final SearchResultEntity result = _results[index];
                      final bool selected = index == _selectedIndex;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Material(
                          color: selected
                              ? theme.colorScheme.primary.withValues(alpha: 0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppRadius.control),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.control),
                            onTap: () => Navigator.of(context).pop(result),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 9,
                              ),
                              child: Row(
                                children: <Widget>[
                                  Icon(_icon(result.entityType), size: 19),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          result.title.trim().isEmpty
                                              ? 'Başlıksız'
                                              : result.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            fontWeight: selected
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                          ),
                                        ),
                                        if (result.preview.trim().isNotEmpty &&
                                            result.preview.trim() !=
                                                result.title.trim())
                                          Text(
                                            result.preview.replaceAll('\n', ' '),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodySmall,
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _typeLabel(result.entityType),
                                    style: theme.textTheme.labelSmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
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
