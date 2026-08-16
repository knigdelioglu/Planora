import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/app/router/app_router.dart';
import 'package:not_app/app/widgets/common_widgets.dart';
import 'package:not_app/features/kanban/presentation/screens/card_detail_screen.dart';
import 'package:not_app/features/kanban/presentation/screens/kanban_board_screen.dart';
import 'package:not_app/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:not_app/features/search/domain/entities/search_result.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.autofocus = false});
  final bool autofocus;
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _query = TextEditingController();
  Timer? _debounce;
  List<SearchResultEntity> _results = const <SearchResultEntity>[];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _query.addListener(_changed);
  }

  void _changed() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), _search);
  }

  Future<void> _search() async {
    final String value = _query.text.trim();
    if (value.isEmpty) {
      setState(() => _results = const <SearchResultEntity>[]);
      return;
    }
    setState(() => _busy = true);
    final data = await ref.read(searchRepositoryProvider).search(value);
    if (mounted) {
      setState(() {
        _results = data;
        _busy = false;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      const AppPageHeader(
        title: 'Arama',
        subtitle: 'Notlar, kartlar ve panolar arasında tamamen yerel arama.',
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: TextField(
          controller: _query,
          autofocus: widget.autofocus,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Ara…',
            suffixIcon: _busy
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
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
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                itemCount: _results.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final result = _results[index];
                  final icon = switch (result.entityType) {
                    'note' => Icons.description_outlined,
                    'card' => Icons.view_agenda_outlined,
                    _ => Icons.view_kanban_outlined,
                  };
                  return ListTile(
                    leading: Icon(icon),
                    title: Text(
                      result.title.isEmpty ? 'Başlıksız' : result.title,
                    ),
                    subtitle: Text(
                      result.preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _open(result),
                  );
                },
              ),
      ),
    ],
  );
}
