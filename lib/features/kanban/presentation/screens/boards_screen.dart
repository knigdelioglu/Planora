import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/app/router/app_router.dart';
import 'package:not_app/app/widgets/common_widgets.dart';
import 'package:not_app/features/kanban/domain/entities/board.dart';
import 'package:not_app/features/kanban/presentation/screens/kanban_board_screen.dart';

class BoardsScreen extends ConsumerWidget {
  const BoardsScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final String? title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni pano'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Pano adı')),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Oluştur')),
        ],
      ),
    );
    controller.dispose();
    if (title == null || title.isEmpty) return;
    final String id = await ref.read(kanbanRepositoryProvider).createBoard(title: title);
    if (!context.mounted) return;
    await AppRouter.push<void>(context, KanbanBoardScreen(boardId: id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(kanbanRepositoryProvider);
    return Column(
      children: <Widget>[
        AppPageHeader(
          title: 'Panolar',
          subtitle: 'İşleri kolonlar ve kartlarla düzenleyin.',
          actions: <Widget>[FilledButton.icon(onPressed: () => _create(context, ref), icon: const Icon(Icons.add), label: const Text('Yeni pano'))],
        ),
        Expanded(
          child: StreamBuilder<List<BoardEntity>>(
            stream: repo.watchBoards(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return ErrorState(message: snapshot.error.toString());
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final boards = snapshot.requireData;
              if (boards.isEmpty) {
                return EmptyState(
                  icon: Icons.view_kanban_outlined,
                  title: 'Henüz pano yok',
                  message: 'İlk panonuzu oluşturup kartlarınızı düzenlemeye başlayın.',
                  action: FilledButton(onPressed: () => _create(context, ref), child: const Text('Pano oluştur')),
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 360, mainAxisExtent: 150, crossAxisSpacing: 12, mainAxisSpacing: 12),
                itemCount: boards.length,
                itemBuilder: (context, index) {
                  final board = boards[index];
                  return Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => AppRouter.push<void>(context, KanbanBoardScreen(boardId: board.id)),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(children: <Widget>[Icon(Icons.view_kanban_outlined, color: Theme.of(context).colorScheme.primary), const Spacer(), _BoardMenu(board: board)]),
                            const Spacer(),
                            Text(board.title, style: Theme.of(context).textTheme.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text('Son değişiklik: ${MaterialLocalizations.of(context).formatShortDate(board.updatedAt.toLocal())}', style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ),
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

class _BoardMenu extends ConsumerWidget {
  const _BoardMenu({required this.board});
  final BoardEntity board;
  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<String>(
        onSelected: (value) async {
          if (value == 'rename') {
            final controller = TextEditingController(text: board.title);
            final String? title = await showDialog<String>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Panoyu yeniden adlandır'),
                content: TextField(controller: controller, autofocus: true),
                actions: <Widget>[
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
                  FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Kaydet')),
                ],
              ),
            );
            controller.dispose();
            if (title != null && title.isNotEmpty) await ref.read(kanbanRepositoryProvider).renameBoard(board.id, title);
          }
          if (value == 'delete') {
            final bool ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Pano silinsin mi?'),
                    content: const Text('Pano ve içindeki kartlar çöp işaretiyle senkronize edilmek üzere kaldırılır.'),
                    actions: <Widget>[
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
                      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
                    ],
                  ),
                ) ??
                false;
            if (ok) await ref.read(kanbanRepositoryProvider).deleteBoard(board.id);
          }
        },
        itemBuilder: (_) => const <PopupMenuEntry<String>>[
          PopupMenuItem(value: 'rename', child: Text('Yeniden adlandır')),
          PopupMenuItem(value: 'delete', child: Text('Sil')),
        ],
      );
}
