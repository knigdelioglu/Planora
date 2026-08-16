import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/app/widgets/common_widgets.dart';
import 'package:not_app/features/reminders/domain/entities/reminder.dart';
import 'package:not_app/features/reminders/presentation/reminder_widgets.dart';

enum _ReminderView { upcoming, past, disabled }

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});
  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  _ReminderView _view = _ReminderView.upcoming;

  Future<void> _requestPermissions() async {
    final state = await ref
        .read(notificationServiceProvider)
        .requestPermissions();
    if (!mounted) return;
    final String message = state.notificationsAllowed
        ? state.exactAlarmsAllowed
              ? 'Bildirim izinleri hazır.'
              : 'Bildirim izni açık; kesin alarm izni cihaz tarafından sınırlanıyor.'
        : 'Bildirim izni verilmedi. Ayarlardan daha sonra açabilirsiniz.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    await ref.read(remindersRepositoryProvider).reconcile();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(remindersRepositoryProvider);
    final Stream<List<ReminderEntity>> stream = switch (_view) {
      _ReminderView.upcoming => repo.watchUpcoming(),
      _ReminderView.past => repo.watchPast(),
      _ReminderView.disabled => repo.watchDisabled(),
    };
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
                          ? item.schedulingStatus == 'scheduled'
                                ? Icons.notifications_active_outlined
                                : Icons.notifications_none
                          : Icons.notifications_off_outlined,
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
