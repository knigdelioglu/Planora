import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/app/router/app_router.dart';
import 'package:not_app/app/theme/app_theme.dart';
import 'package:not_app/app/widgets/feedback/app_feedback.dart';
import 'package:not_app/app/widgets/navigation/app_sidebar_item.dart';
import 'package:not_app/app/widgets/overlays/global_search_palette.dart';
import 'package:not_app/core/sync/sync_coordinator.dart';
import 'package:not_app/features/home/presentation/home_screen.dart';
import 'package:not_app/features/kanban/presentation/screens/boards_screen.dart';
import 'package:not_app/features/kanban/presentation/screens/card_detail_screen.dart';
import 'package:not_app/features/kanban/presentation/screens/kanban_board_screen.dart';
import 'package:not_app/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:not_app/features/notes/presentation/screens/notes_screen.dart';
import 'package:not_app/features/reminders/presentation/screens/reminders_screen.dart';
import 'package:not_app/features/search/domain/entities/search_result.dart';
import 'package:not_app/features/search/presentation/screens/search_screen.dart';
import 'package:not_app/features/settings/presentation/settings_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  static const List<_Destination> _mainDestinations = <_Destination>[
    _Destination('Ana Sayfa', Icons.home_outlined, Icons.home_rounded),
    _Destination(
      'Notlar',
      Icons.description_outlined,
      Icons.description_rounded,
    ),
    _Destination(
      'Panolar',
      Icons.view_kanban_outlined,
      Icons.view_kanban_rounded,
    ),
    _Destination(
      'Hatırlatıcılar',
      Icons.notifications_none_rounded,
      Icons.notifications_rounded,
    ),
  ];

  Widget _page(int index) => switch (index) {
    0 => const HomeScreen(),
    1 => const NotesScreen(),
    2 => const BoardsScreen(),
    3 => const RemindersScreen(),
    _ => const SettingsScreen(),
  };

  Future<void> _newNote() async {
    final String id = await ref.read(notesRepositoryProvider).createNote();
    if (!mounted) return;
    await AppRouter.push<void>(context, NoteEditorScreen(noteId: id));
  }

  Future<void> _openSearch() async {
    final double width = MediaQuery.sizeOf(context).width;
    if (width < AppBreakpoints.compact) {
      await AppRouter.push<void>(context, const SearchScreen(autofocus: true));
      return;
    }

    final SearchResultEntity? result = await showDialog<SearchResultEntity>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const GlobalSearchPalette(),
    );
    if (!mounted || result == null) return;
    await _openSearchResult(result);
  }

  Future<void> _openSearchResult(SearchResultEntity result) async {
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

  void _openSettings() {
    final double width = MediaQuery.sizeOf(context).width;
    if (width < AppBreakpoints.compact) {
      AppRouter.push<void>(context, const SettingsScreen());
    } else {
      setState(() => _index = 4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(appServicesProvider);
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () {
          _openSearch();
        },
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
          _openSearch();
        },
        const SingleActivator(
          LogicalKeyboardKey.keyN,
          meta: true,
          shift: true,
        ): () {
          _newNote();
        },
        const SingleActivator(
          LogicalKeyboardKey.keyN,
          control: true,
          shift: true,
        ): () {
          _newNote();
        },
        const SingleActivator(LogicalKeyboardKey.comma, meta: true):
            _openSettings,
        const SingleActivator(LogicalKeyboardKey.comma, control: true):
            _openSettings,
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth;
            if (width < AppBreakpoints.compact) {
              return _compact(
                services.config.cloudConfigured,
                services.auth.currentState.isSignedIn,
              );
            }
            if (width < AppBreakpoints.expanded) {
              return _medium(
                services.config.cloudConfigured,
                services.auth.currentState.isSignedIn,
              );
            }
            return _expanded(
              services.config.cloudConfigured,
              services.auth.currentState.isSignedIn,
            );
          },
        ),
      ),
    );
  }

  Widget _sync(bool configured, bool signedIn) {
    final coordinator = ref.watch(syncCoordinatorProvider);
    return StreamBuilder<int>(
      stream: ref.watch(syncQueueRepositoryProvider).watchPendingCount(),
      initialData: 0,
      builder: (context, pendingSnapshot) => StreamBuilder<SyncHealthState>(
        stream: coordinator.watchHealth(),
        initialData: coordinator.currentHealth,
        builder: (context, healthSnapshot) {
          final SyncHealthState health =
              healthSnapshot.data ?? coordinator.currentHealth;
          final int pending = pendingSnapshot.data ?? 0;
          final String label;
          final IconData icon;
          final AppBannerTone tone;
          if (!configured) {
            label = 'Yalnız cihaz';
            icon = Icons.cloud_off_outlined;
            tone = AppBannerTone.info;
          } else if (!signedIn) {
            label = 'Bulut bağlı değil';
            icon = Icons.cloud_outlined;
            tone = AppBannerTone.info;
          } else if (health.isSyncing) {
            label = 'Eşitleniyor…';
            icon = Icons.sync_rounded;
            tone = AppBannerTone.info;
          } else if (health.isOnline == false) {
            label = 'Çevrimdışı';
            icon = Icons.cloud_off_outlined;
            tone = AppBannerTone.warning;
          } else if (health.lastError?.trim().isNotEmpty == true) {
            label = 'Eşitleme sorunu';
            icon = Icons.sync_problem_outlined;
            tone = AppBannerTone.error;
          } else if (pending > 0) {
            label = '$pending değişiklik bekliyor';
            icon = Icons.sync_rounded;
            tone = AppBannerTone.warning;
          } else {
            label = 'Güncel';
            icon = Icons.cloud_done_outlined;
            tone = AppBannerTone.success;
          }
          return AppStatusChip(label: label, icon: icon, tone: tone);
        },
      ),
    );
  }

  Widget _expanded(bool configured, bool signedIn) => Scaffold(
    body: Row(
      children: <Widget>[
        Container(
          width: 228,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              right: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.75),
              ),
            ),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'N',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Not',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                  child: Material(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    child: InkWell(
                      onTap: _openSearch,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.search_rounded,
                              size: 19,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'Ara',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            Text(
                              '⌘K',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                ...List<Widget>.generate(_mainDestinations.length, (index) {
                  final item = _mainDestinations[index];
                  return AppSidebarItem(
                    label: item.label,
                    icon: item.icon,
                    selectedIcon: item.selectedIcon,
                    selected: _index == index,
                    onTap: () => setState(() => _index = index),
                  );
                }),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                  child: _sync(configured, signedIn),
                ),
                AppSidebarItem(
                  label: 'Ayarlar',
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings_rounded,
                  selected: _index == 4,
                  onTap: () => setState(() => _index = 4),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
        Expanded(child: _page(_index)),
      ],
    ),
  );

  Widget _medium(bool configured, bool signedIn) => Scaffold(
    body: Row(
      children: <Widget>[
        SafeArea(
          child: NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            labelType: NavigationRailLabelType.selected,
            leading: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'N',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Ara · ⌘K',
                  onPressed: _openSearch,
                  icon: const Icon(Icons.search_rounded),
                ),
              ],
            ),
            trailing: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Tooltip(
                message: configured && signedIn
                    ? 'Bulut bağlantısı açık'
                    : 'Yalnız cihaz',
                child: Icon(
                  configured && signedIn
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_off_outlined,
                  size: 18,
                ),
              ),
            ),
            destinations: <NavigationRailDestination>[
              ..._mainDestinations.map(
                (item) => NavigationRailDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon),
                  label: Text(item.label),
                ),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: Text('Ayarlar'),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: _page(_index)),
      ],
    ),
  );

  Widget _compact(bool configured, bool signedIn) {
    final int bottomIndex = _index <= 3 ? _index : 4;
    final Widget body = bottomIndex == 4
        ? _CompactMore(
            onSearch: () => AppRouter.push<void>(
              context,
              const SearchScreen(autofocus: true),
            ),
            onSettings: () =>
                AppRouter.push<void>(context, const SettingsScreen()),
            sync: _sync(configured, signedIn),
          )
        : _page(_index);
    return Scaffold(
      body: SafeArea(bottom: false, child: body),
      bottomNavigationBar: NavigationBar(
        selectedIndex: bottomIndex,
        onDestinationSelected: (value) =>
            setState(() => _index = value == 4 ? 4 : value),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Ana',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description_rounded),
            label: 'Notlar',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_kanban_outlined),
            selectedIcon: Icon(Icons.view_kanban_rounded),
            label: 'Panolar',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none_rounded),
            selectedIcon: Icon(Icons.notifications_rounded),
            label: 'Hatırlatıcı',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded),
            label: 'Daha',
          ),
        ],
      ),
    );
  }
}

class _CompactMore extends StatelessWidget {
  const _CompactMore({
    required this.onSearch,
    required this.onSettings,
    required this.sync,
  });

  final VoidCallback onSearch;
  final VoidCallback onSettings;
  final Widget sync;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
    children: <Widget>[
      Text('Daha', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 14),
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        leading: const Icon(Icons.search_rounded),
        title: const Text('Arama'),
        onTap: onSearch,
      ),
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        leading: const Icon(Icons.settings_outlined),
        title: const Text('Ayarlar'),
        onTap: onSettings,
      ),
      const SizedBox(height: 10),
      Divider(color: Theme.of(context).dividerColor),
      const SizedBox(height: 10),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: sync),
    ],
  );
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
