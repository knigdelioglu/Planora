import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/app/router/app_router.dart';
import 'package:not_app/app/theme/app_theme.dart';
import 'package:not_app/app/widgets/common_widgets.dart';
import 'package:not_app/core/sync/sync_coordinator.dart';
import 'package:not_app/features/home/presentation/home_screen.dart';
import 'package:not_app/features/kanban/presentation/screens/boards_screen.dart';
import 'package:not_app/features/notes/presentation/screens/notes_screen.dart';
import 'package:not_app/features/reminders/presentation/screens/reminders_screen.dart';
import 'package:not_app/features/search/presentation/screens/search_screen.dart';
import 'package:not_app/features/settings/presentation/settings_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  static const List<_Destination> _destinations = <_Destination>[
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
      Icons.notifications_none,
      Icons.notifications_rounded,
    ),
    _Destination('Arama', Icons.search_outlined, Icons.search_rounded),
    _Destination('Ayarlar', Icons.settings_outlined, Icons.settings_rounded),
  ];

  Widget _page(int index) => switch (index) {
    0 => const HomeScreen(),
    1 => const NotesScreen(),
    2 => const BoardsScreen(),
    3 => const RemindersScreen(),
    4 => const SearchScreen(),
    _ => const SettingsScreen(),
  };

  void _openSearch() => setState(() => _index = 4);

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(appServicesProvider);
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): _openSearch,
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _openSearch,
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
          return SyncStatusIndicator(
            pendingCount: pendingSnapshot.data ?? 0,
            cloudConfigured: configured,
            signedIn: signedIn,
            isSyncing: health.isSyncing,
            isOnline: health.isOnline,
            lastSuccessfulSyncAt: health.lastSuccessfulSyncAt,
            lastError: health.lastError,
          );
        },
      ),
    );
  }

  Widget _expanded(bool configured, bool signedIn) => Scaffold(
    body: Row(
      children: <Widget>[
        Container(
          width: 248,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              right: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: SafeArea(
            child: Column(
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Not',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _destinations.length,
                    itemBuilder: (context, index) {
                      final item = _destinations[index];
                      return ListTile(
                        selected: _index == index,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        leading: Icon(
                          _index == index ? item.selectedIcon : item.icon,
                        ),
                        title: Text(item.label),
                        onTap: () => setState(() => _index = index),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: _sync(configured, signedIn),
                ),
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
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text('Not', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            trailing: Padding(
              padding: const EdgeInsets.only(top: 18),
              child: _sync(configured, signedIn),
            ),
            destinations: _destinations
                .map(
                  (item) => NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: Text(item.label),
                  ),
                )
                .toList(),
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
            onSearch: () =>
                AppRouter.push(context, const SearchScreen(autofocus: true)),
            onSettings: () => AppRouter.push(context, const SettingsScreen()),
            sync: _sync(configured, signedIn),
          )
        : _page(_index);
    return Scaffold(
      body: SafeArea(bottom: false, child: body),
      bottomNavigationBar: NavigationBar(
        selectedIndex: bottomIndex,
        onDestinationSelected: (value) =>
            setState(() => _index = value == 4 ? 5 : value),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Ana',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: 'Notlar',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_kanban_outlined),
            selectedIcon: Icon(Icons.view_kanban),
            label: 'Panolar',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(Icons.notifications),
            label: 'Hatırlatıcı',
          ),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Daha'),
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
    padding: const EdgeInsets.all(16),
    children: <Widget>[
      Text('Daha', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 16),
      ListTile(
        leading: const Icon(Icons.search),
        title: const Text('Arama'),
        trailing: const Text('⌘K'),
        onTap: onSearch,
      ),
      ListTile(
        leading: const Icon(Icons.settings_outlined),
        title: const Text('Ayarlar'),
        onTap: onSettings,
      ),
      const Divider(),
      Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: sync),
    ],
  );
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
