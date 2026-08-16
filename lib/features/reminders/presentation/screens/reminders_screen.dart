import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/app/widgets/common_widgets.dart';
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
    if (state == AppLifecycleState.resumed) {
      _loadPermissions();
    }
  }

  Future<void> _loadPermissions() async {
    if (!mounted) return;
    try {
      final state = await ref
          .read(notificationServiceProvider)
          .permissionState();
      if (mounted) {
        setState(() => _permissionState = state);
      }
    } catch (_) {}
  }

  Future<void> _requestPermissions() async {
    final state = await ref
        .read(notificationServiceProvider)
        .requestPermissions();
    if (!mounted) return;
    setState(() => _permissionState = state);
    final String message = state.notificationsAllowed
        ? state.exactAlarmsAllowed
              ? 'Bildirim izinleri hazır.'
              : 'Bildirim izni açık; kesin alarm izni olmadığı için inexact mod devrede.'
        : 'Bildirim izni verilmedi. Ayarlardan daha sonra açabilirsiniz.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    await ref.read(remindersRepositoryProvider).reconcile();
  }

  Future<void> _openAppSettings() async {
    final opened = await ref
        .read(notificationServiceProvider)
        .openAppSettings();
    if (!mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ayarlar sayfası açılamadı. Lütfen cihaz ayarlarından kontrol edin.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(remindersRepositoryProvider);
    final Stream<List<ReminderEntity>> stream = switch (_view) {
      _ReminderView.upcoming => repo.watchUpcoming(),
      _ReminderView.past => repo.watchPast(),
      _ReminderView.disabled => repo.watchDisabled(),
    };
    final NotificationPermissionState permState =
        _permissionState ??
        const NotificationPermissionState(
          notificationsAllowed: true,
          exactAlarmsAllowed: true,
        );

    return Column(
      children: <Widget>[
        AppPageHeader(
          title: 'Hatırlatıcılar',
          subtitle: 'Not ve kartlara bağlı cihaz bildirimleri.',
          actions: <Widget>[
            OutlinedButton.icon(
              onPressed: _requestPermissions,
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('İzinleri kontrol et'),
            ),
          ],
        ),
        if (permState.isDenied)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.errorContainer.withAlpha(50),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.error),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.notifications_off_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Bildirim izni kapalı. Hatırlatıcıların çalması için lütfen izin verin.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _requestPermissions,
                    child: const Text('İzin İste'),
                  ),
                  FilledButton.tonal(
                    onPressed: _openAppSettings,
                    child: const Text('Ayarları Aç'),
                  ),
                ],
              ),
            ),
          )
        else if (permState.hasInexactFallbackOnly)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.info_outline, color: Colors.orange),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Kesin alarm izni kapalı. Hatırlatıcılar inexact modda planlandı ve yaklaşık zamanda gelecektir.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: _openAppSettings,
                    child: const Text('Ayarları Aç'),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<_ReminderView>(
              segments: const <ButtonSegment<_ReminderView>>[
                ButtonSegment(
                  value: _ReminderView.upcoming,
                  label: Text('Yaklaşan'),
                ),
                ButtonSegment(value: _ReminderView.past, label: Text('Geçmiş')),
                ButtonSegment(
                  value: _ReminderView.disabled,
                  label: Text('Devre dışı'),
                ),
              ],
              selected: <_ReminderView>{_view},
              onSelectionChanged: (value) =>
                  setState(() => _view = value.first),
              showSelectedIcon: false,
            ),
          ),
        ),
        const SizedBox(height: 12),
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
              final data = snapshot.requireData;
              if (data.isEmpty) {
                return EmptyState(
                  icon: _view == _ReminderView.disabled
                      ? Icons.notifications_off_outlined
                      : Icons.notifications_none,
                  title: _view == _ReminderView.disabled
                      ? 'Devre dışı hatırlatıcı yok'
                      : 'Hatırlatıcı yok',
                  message: _view == _ReminderView.upcoming
                      ? 'Not veya kart ayrıntısından bir tarih ve saat belirleyebilirsiniz.'
                      : _view == _ReminderView.past
                      ? 'Geçmiş etkin hatırlatıcılar burada görünür.'
                      : 'Kapattığınız hatırlatıcılar burada saklanır ve yeniden açılabilir.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                itemCount: data.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final ReminderEntity item = data[index];
                  return ListTile(
                    leading: Icon(
                      item.enabled
                          ? switch (item.schedulingStatus) {
                              'scheduled' =>
                                Icons.notifications_active_outlined,
                              'inexact' => Icons.alarm_outlined,
                              'failed' => Icons.error_outline,
                              _ => Icons.notifications_none,
                            }
                          : Icons.notifications_off_outlined,
                      color: item.enabled
                          ? switch (item.schedulingStatus) {
                              'scheduled' => Colors.green,
                              'inexact' => Colors.orange,
                              'failed' => Theme.of(context).colorScheme.error,
                              _ => null,
                            }
                          : null,
                    ),
                    title: Text(item.title),
                    subtitle: Text(reminderSubtitle(context, item)),
                    onTap: () => editReminderEntity(context, ref, item),
                    trailing: SizedBox(
                      width: 104,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
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
                                await repo.remove(item.id);
                              }
                            },
                            itemBuilder: (_) => const <PopupMenuEntry<String>>[
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Düzenle'),
                              ),
                              PopupMenuItem(
                                value: 'snooze',
                                child: Text('10 dk ertele'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Sil'),
                              ),
                            ],
                          ),
                        ],
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
