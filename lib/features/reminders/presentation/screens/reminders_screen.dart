import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/app/widgets/common_widgets.dart';
import 'package:not_app/features/reminders/domain/entities/reminder.dart';

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});
  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  bool _past = false;

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
            child: SegmentedButton<bool>(
              segments: const <ButtonSegment<bool>>[
                ButtonSegment(value: false, label: Text('Yaklaşan')),
                ButtonSegment(value: true, label: Text('Geçmiş')),
              ],
              selected: <bool>{_past},
              onSelectionChanged: (value) =>
                  setState(() => _past = value.first),
              showSelectedIcon: false,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<List<ReminderEntity>>(
            stream: _past ? repo.watchPast() : repo.watchUpcoming(),
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return ErrorState(message: snapshot.error.toString());
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final data = snapshot.requireData;
              if (data.isEmpty) {
                return const EmptyState(
                  icon: Icons.notifications_none,
                  title: 'Hatırlatıcı yok',
                  message:
                      'Not veya kart ayrıntısından bir tarih ve saat belirleyebilirsiniz.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                itemCount: data.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = data[index];
                  return ListTile(
                    leading: Icon(
                      item.schedulingStatus == 'scheduled'
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_none,
                    ),
                    title: Text(item.title),
                    subtitle: Text(
                      '${MaterialLocalizations.of(context).formatFullDate(item.scheduledAtUtc.toLocal())} · ${TimeOfDay.fromDateTime(item.scheduledAtUtc.toLocal()).format(context)} · ${item.schedulingStatus}',
                    ),
                    trailing: item.deletedAt == null
                        ? IconButton(
                            tooltip: 'Hatırlatıcıyı sil',
                            onPressed: () => repo.remove(item.id),
                            icon: const Icon(Icons.delete_outline),
                          )
                        : null,
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
