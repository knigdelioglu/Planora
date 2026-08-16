import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/app/widgets/common_widgets.dart' show EmptyState, ErrorState;
import 'package:not_app/app/widgets/content/app_content.dart';
import 'package:not_app/app/widgets/feedback/app_feedback.dart';
import 'package:not_app/app/widgets/navigation/app_toolbar.dart';
import 'package:not_app/core/services/notification_service.dart';
import 'package:not_app/features/reminders/domain/entities/reminder.dart';
import 'package:not_app/features/reminders/presentation/reminder_widgets.dart';

enum _ReminderView { upcoming, past, disabled }

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen>
    with WidgetsBindingObserver {
  _ReminderView _view = _ReminderView.upcoming;
  NotificationPermissionState? _permissionState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    try {
      final NotificationPermissionState state =
          await ref.read(notificationServiceProvider).permissionState();
      if (mounted) setState(() => _permissionState = state);
    } catch (_) {}
  }

  Future<void> _requestPermissions() async {
    final NotificationPermissionState state =
        await ref.read(notificationServiceProvider).requestPermissions();
    if (!mounted) return;
    setState(() => _permissionState = state);
    await ref.read(remindersRepositoryProvider).reconcile();
  }

  Future<void> _openAppSettings() async {
    final bool opened =
        await ref.read(notificationServiceProvider).openAppSettings();
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sistem ayarları açılamadı.')),
    );
  }

  String _viewLabel(_ReminderView value) => switch (value) {
        _ReminderView.upcoming => 'Yaklaşan',
        _ReminderView.past => 'Geçmiş',
        _ReminderView.disabled => 'Devre dışı',
      };

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(remindersRepositoryProvider);
    final Stream<List<ReminderEntity>> stream = switch (_view) {
      _ReminderView.upcoming => repo.watchUpcoming(),
      _ReminderView.past => repo.watchPast(),
      _ReminderView.disabled => repo.watchDisabled(),
    };
    final NotificationPermissionState permission =
        _permissionState ??
        const NotificationPermissionState(
          notificationsAllowed: true,
          exactAlarmsAllowed: true,
        );

    return Column(
      children: <Widget>[
        AppToolbar(
          title: 'Hatırlatıcılar',
          actions: <Widget>[
            PopupMenuButton<String>(
              tooltip: 'Bildirim ayarları',
              onSelected: (value) {
                if (value == 'check') _requestPermissions();
                if (value == 'settings') _openAppSettings();
              },
              itemBuilder: (_) => const <PopupMenuEntry<String>>[
                PopupMenuItem(
                  value: 'check',
                  child: Text('Bildirim izinlerini kontrol et'),
                ),
                PopupMenuItem(
                  value: 'settings',
                  child: Text('Sistem ayarlarını aç'),
                ),
              ],
              icon: const Icon(Icons.notifications_outlined),
            ),
          ],
        ),
        if (permission.isDenied)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: AppBanner(
              tone: AppBannerTone.warning,
              message:
                  'Bildirimler kapalı. Hatırlatıcılar kaydedilir ancak cihaz bildirimi gösterilemez.',
              action: TextButton(
                onPressed: _openAppSettings,
                child: const Text('Ayarları aç'),
              ),
            ),
          )
        else if (permission.hasInexactFallbackOnly)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: AppBanner(
              tone: AppBannerTone.info,
              message: 'Bazı hatırlatıcılar yaklaşık zamanda bildirilebilir.',
              action: TextButton(
                onPressed: _openAppSettings,
                child: const Text('Kontrol et'),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: _ReminderView.values
                  .map(
                    (value) => ChoiceChip(
                      label: Text(_viewLabel(value)),
                      selected: _view == value,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _view = value),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ReminderEntity>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorState(message: snapshot.error.toString());
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final List<ReminderEntity> data = snapshot.requireData;
              if (data.isEmpty) {
                return EmptyState(
                  icon: _view == _ReminderView.disabled
                      ? Icons.notifications_off_outlined
                      : Icons.notifications_none_rounded,
                  title: _view == _ReminderView.disabled
                      ? 'Devre dışı hatırlatıcı yok'
                      : 'Hatırlatıcı yok',
                  message: _view == _ReminderView.upcoming
                      ? 'Notlara veya kartlara tarih eklediğinizde burada görünür.'
                      : _view == _ReminderView.past
                          ? 'Geçmiş hatırlatıcılar burada görünür.'
                          : 'Kapattığınız hatırlatıcılar burada saklanır.',
                );
              }
              if (_view == _ReminderView.upcoming) {
                return _GroupedReminderList(data: data);
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                itemCount: data.length,
                itemBuilder: (context, index) =>
                    _ReminderRow(item: data[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GroupedReminderList extends StatelessWidget {
  const _GroupedReminderList({required this.data});

  final List<ReminderEntity> data;

  String _group(DateTime local, DateTime now) {
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime day = DateTime(local.year, local.month, local.day);
    final int difference = day.difference(today).inDays;
    if (difference <= 0) return 'Bugün';
    if (difference == 1) return 'Yarın';
    if (difference <= 7) return 'Bu hafta';
    return 'Daha sonra';
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final Map<String, List<ReminderEntity>> groups = <String, List<ReminderEntity>>{
      'Bugün': <ReminderEntity>[],
      'Yarın': <ReminderEntity>[],
      'Bu hafta': <ReminderEntity>[],
      'Daha sonra': <ReminderEntity>[],
    };
    for (final ReminderEntity item in data) {
      groups[_group(item.scheduledAtUtc.toLocal(), now)]!.add(item);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: <Widget>[
        for (final MapEntry<String, List<ReminderEntity>> entry in groups.entries)
          if (entry.value.isNotEmpty) ...<Widget>[
            AppSectionHeader(
              title: entry.key,
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 5),
            ),
            ...entry.value.map((item) => _ReminderRow(item: item)),
          ],
      ],
    );
  }
}

class _ReminderRow extends ConsumerWidget {
  const _ReminderRow({required this.item});

  final ReminderEntity item;

  String _statusText() => switch (item.schedulingStatus) {
        'failed' => 'Bildirim planlanamadı',
        'inexact' => 'Yaklaşık zamanda bildirilecek',
        'scheduled' => 'Bildirim hazır',
        _ => item.enabled ? 'Etkin' : 'Kapalı',
      };

  IconData _statusIcon() => switch (item.schedulingStatus) {
        'failed' => Icons.error_outline_rounded,
        'inexact' => Icons.schedule_rounded,
        'scheduled' => Icons.notifications_active_outlined,
        _ => item.enabled
            ? Icons.notifications_none_rounded
            : Icons.notifications_off_outlined,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime local = item.scheduledAtUtc.toLocal();
    final String time = TimeOfDay.fromDateTime(local).format(context);
    final String date = MaterialLocalizations.of(context).formatShortDate(local);
    return AppListRow(
      leading: SizedBox(
        width: 52,
        child: Text(time, style: Theme.of(context).textTheme.labelLarge),
      ),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('$date · ${_statusText()}'),
      onTap: () => editReminderEntity(context, ref, item),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Tooltip(
            message: _statusText(),
            child: Icon(
              _statusIcon(),
              size: 17,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          Switch.adaptive(
            value: item.enabled,
            onChanged: (value) =>
                setReminderEnabled(context, ref, item, value),
          ),
          PopupMenuButton<String>(
            tooltip: 'Hatırlatıcı işlemleri',
            onSelected: (value) async {
              if (value == 'edit') {
                await editReminderEntity(context, ref, item);
              } else if (value == 'snooze') {
                await snoozeReminder(context, ref, item);
              } else if (value == 'delete') {
                await ref.read(remindersRepositoryProvider).remove(item.id);
              }
            },
            itemBuilder: (_) => const <PopupMenuEntry<String>>[
              PopupMenuItem(value: 'edit', child: Text('Düzenle')),
              PopupMenuItem(value: 'snooze', child: Text('10 dk ertele')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'delete', child: Text('Sil')),
            ],
            icon: const Icon(Icons.more_horiz_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}
