import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/app/router/app_router.dart';
import 'package:not_app/app/theme/app_theme.dart';
import 'package:not_app/app/widgets/common_widgets.dart';
import 'package:not_app/app/widgets/content/app_content.dart';
import 'package:not_app/app/widgets/navigation/app_toolbar.dart';
import 'package:not_app/features/kanban/domain/entities/board.dart';
import 'package:not_app/features/kanban/presentation/screens/kanban_board_screen.dart';
import 'package:not_app/features/kanban/presentation/widgets/kanban_color.dart';

class BoardsScreen extends ConsumerWidget {
  const BoardsScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final TitleColorValue? value = await showTitleColorDialog(
      context,
      dialogTitle: 'Yeni pano',
      fieldLabel: 'Pano adı',
      confirmLabel: 'Oluştur',
    );
    if (value == null) return;
    final String id = await ref
        .read(kanbanRepositoryProvider)
        .createBoard(title: value.title, colorHex: value.colorHex);
    if (!context.mounted) return;
    await AppRouter.push<void>(context, KanbanBoardScreen(boardId: id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(kanbanRepositoryProvider);
    final settings = ref.watch(settingsRepositoryProvider);
    return Column(
      children: <Widget>[
        AppToolbar(
          title: 'Panolar',
          actions: <Widget>[
            FilledButton.icon(
              onPressed: () => _create(context, ref),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Yeni pano'),
            ),
          ],
        ),
        Expanded(
          child: StreamBuilder<List<BoardEntity>>(
            stream: repo.watchBoards(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorState(message: snapshot.error.toString());
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final List<BoardEntity> boards = snapshot.requireData;
              if (boards.isEmpty) {
                return EmptyState(
                  icon: Icons.view_kanban_outlined,
                  title: 'Henüz pano yok',
                  message:
                      'İşlerini kolonlar ve kartlarla düzenlemek için ilk panonu oluştur.',
                  action: FilledButton(
                    onPressed: () => _create(context, ref),
                    child: const Text('Pano oluştur'),
                  ),
                );
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  final double horizontal = constraints.maxWidth < 600 ? 16 : 24;
                  return GridView.builder(
                    padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 36),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 340,
                      mainAxisExtent: 132,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: boards.length,
                    itemBuilder: (context, index) {
                      final BoardEntity board = boards[index];
                      return StreamBuilder<String?>(
                        stream: settings.watchEntityColor('board', board.id),
                        builder: (context, colorSnapshot) {
                          final Color? accent = colorFromHex(
                            colorSnapshot.data ?? board.colorHex,
                          );
                          final Color surface = tintedSurface(
                            context,
                            accent,
                            opacity: Theme.of(context).brightness == Brightness.dark
                                ? 0.22
                                : 0.15,
                          );
                          final Color borderColor = accent == null
                              ? Theme.of(context)
                                  .dividerColor
                                  .withValues(alpha: 0.7)
                              : accent.withValues(alpha: 0.36);

                          return Material(
                            color: surface,
                            borderRadius:
                                BorderRadius.circular(AppRadius.surface),
                            child: InkWell(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.surface),
                              onTap: () => AppRouter.push<void>(
                                context,
                                KanbanBoardScreen(boardId: board.id),
                              ),
                              child: Container(
                                padding:
                                    const EdgeInsets.fromLTRB(15, 14, 8, 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: borderColor),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.surface),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    AppEntityColorIndicator(
                                      color: accent,
                                      vertical: true,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Expanded(
                                                child: Text(
                                                  board.title,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleLarge,
                                                ),
                                              ),
                                              _BoardMenu(board: board),
                                            ],
                                          ),
                                          const Spacer(),
                                          Row(
                                            children: <Widget>[
                                              Icon(
                                                Icons.view_kanban_outlined,
                                                size: 15,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  'Son değişiklik ${MaterialLocalizations.of(context).formatShortDate(board.updatedAt.toLocal())}',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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

class _BoardMenu extends ConsumerWidget {
  const _BoardMenu({required this.board});

  final BoardEntity board;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<String>(
        tooltip: 'Pano işlemleri',
        onSelected: (value) async {
          if (value == 'rename') {
            final settings = ref.read(settingsRepositoryProvider);
            final String? colorOverride =
                await settings.watchEntityColor('board', board.id).first;
            if (!context.mounted) return;
            final TitleColorValue? result = await showTitleColorDialog(
              context,
              dialogTitle: 'Panoyu düzenle',
              fieldLabel: 'Pano adı',
              initialTitle: board.title,
              initialColorHex: colorOverride ?? board.colorHex,
              confirmLabel: 'Kaydet',
            );
            if (result == null) return;
            final repo = ref.read(kanbanRepositoryProvider);
            if (result.title != board.title) {
              await repo.renameBoard(board.id, result.title);
            }
            final String? nextColorOverride =
                result.colorHex == board.colorHex ? null : result.colorHex;
            await settings.setEntityColor(
              'board',
              board.id,
              nextColorOverride,
            );
          } else if (value == 'delete') {
            final bool ok =
                await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Pano silinsin mi?'),
                    content: const Text(
                      'Pano ve içindeki kartlar kalıcı olarak kaldırılacak.',
                    ),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Vazgeç'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Sil'),
                      ),
                    ],
                  ),
                ) ??
                false;
            if (ok) {
              await ref.read(kanbanRepositoryProvider).deleteBoard(board.id);
            }
          }
        },
        itemBuilder: (_) => const <PopupMenuEntry<String>>[
          PopupMenuItem(value: 'rename', child: Text('Düzenle')),
          PopupMenuDivider(),
          PopupMenuItem(value: 'delete', child: Text('Sil')),
        ],
        icon: const Icon(Icons.more_horiz_rounded, size: 19),
      );
}
