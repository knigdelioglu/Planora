import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/features/reminders/domain/entities/reminder.dart';

final class ReminderDraft {
  const ReminderDraft({
    required this.title,
    required this.body,
    required this.scheduledAtUtc,
    required this.timeZoneId,
    required this.enabled,
  });

  final String title;
  final String? body;
  final DateTime scheduledAtUtc;
  final String timeZoneId;
  final bool enabled;
}

Future<ReminderDraft?> showReminderEditorDialog(
  BuildContext context, {
  ReminderEntity? existing,
  required String defaultTitle,
  String? defaultBody,
  required String timeZoneId,
  bool exactAlarmsAllowed = true,
}) async {
  final TextEditingController title = TextEditingController(
    text: existing?.title ?? defaultTitle,
  );
  final TextEditingController body = TextEditingController(
    text: existing?.body ?? defaultBody ?? '',
  );
  DateTime selectedLocal =
      existing?.scheduledAtUtc.toLocal() ??
      DateTime.now().add(const Duration(hours: 1));
  bool enabled = existing?.enabled ?? true;
  String? validationError;

  final ReminderDraft? result = await showDialog<ReminderDraft>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        Future<void> chooseDate() async {
          final DateTime? picked = await showDatePicker(
            context: context,
            firstDate: DateTime(2000),
            lastDate: DateTime(DateTime.now().year + 10, 12, 31),
            initialDate: selectedLocal,
          );
          if (picked == null) return;
          setDialogState(() {
            selectedLocal = DateTime(
              picked.year,
              picked.month,
              picked.day,
              selectedLocal.hour,
              selectedLocal.minute,
            );
            validationError = null;
          });
        }

        Future<void> chooseTime() async {
          final TimeOfDay? picked = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(selectedLocal),
          );
          if (picked == null) return;
          setDialogState(() {
            selectedLocal = DateTime(
              selectedLocal.year,
              selectedLocal.month,
              selectedLocal.day,
              picked.hour,
              picked.minute,
            );
            validationError = null;
          });
        }

        void save() {
          final String cleanTitle = title.text.trim();
          if (cleanTitle.isEmpty) {
            setDialogState(() => validationError = 'Başlık boş olamaz.');
            return;
          }
          if (enabled && !selectedLocal.isAfter(DateTime.now())) {
            setDialogState(
              () => validationError =
                  'Etkin bir hatırlatıcı için gelecek bir tarih ve saat seçin.',
            );
            return;
          }
          final String cleanBody = body.text.trim();
          Navigator.pop(
            context,
            ReminderDraft(
              title: cleanTitle,
              body: cleanBody.isEmpty ? null : cleanBody,
              scheduledAtUtc: selectedLocal.toUtc(),
              timeZoneId: existing?.timeZoneId ?? timeZoneId,
              enabled: enabled,
            ),
          );
        }

        return AlertDialog(
          title: Text(
            existing == null ? 'Hatırlatıcı ekle' : 'Hatırlatıcıyı düzenle',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  controller: title,
                  autofocus: existing == null,
                  decoration: const InputDecoration(labelText: 'Başlık'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: body,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Açıklama'),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: chooseDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        MaterialLocalizations.of(
                          context,
                        ).formatFullDate(selectedLocal),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: chooseTime,
                      icon: const Icon(Icons.schedule_outlined),
                      label: Text(
                        TimeOfDay.fromDateTime(selectedLocal).format(context),
                      ),
                    ),
                  ],
                ),
                if (!exactAlarmsAllowed) ...<Widget>[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: const Row(
                      children: <Widget>[
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: Colors.orange,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Kesin alarm izni verilmediği için bu hatırlatıcı inexact modda yaklaşık bir zamanda çalacaktır.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (existing != null) ...<Widget>[
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Etkin'),
                    subtitle: const Text(
                      'Kapalıyken cihaz bildirimi planlanmaz; daha sonra yeniden açabilirsiniz.',
                    ),
                    value: enabled,
                    onChanged: (value) => setDialogState(() {
                      enabled = value;
                      validationError = null;
                    }),
                  ),
                ],
                if (validationError != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    validationError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Vazgeç'),
            ),
            FilledButton(onPressed: save, child: const Text('Kaydet')),
          ],
        );
      },
    ),
  );

  title.dispose();
  body.dispose();
  return result;
}

Future<void> createReminderForParent(
  BuildContext context,
  WidgetRef ref, {
  required String parentType,
  required String parentId,
  required String defaultTitle,
  String? defaultBody,
}) async {
  final notifService = ref.read(notificationServiceProvider);
  final String zone = notifService.localTimeZoneId;
  final permState = await notifService.permissionState();
  if (!context.mounted) return;
  final ReminderDraft? draft = await showReminderEditorDialog(
    context,
    defaultTitle: defaultTitle,
    defaultBody: defaultBody,
    timeZoneId: zone,
    exactAlarmsAllowed: permState.exactAlarmsAllowed,
  );
  if (draft == null) return;
  try {
    final created = await ref
        .read(remindersRepositoryProvider)
        .create(
          parentType: parentType,
          parentId: parentId,
          title: draft.title,
          body: draft.body,
          scheduledAtUtc: draft.scheduledAtUtc,
          timeZoneId: draft.timeZoneId,
        );
    if (context.mounted && created.schedulingStatus == 'inexact') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Hatırlatıcı kaydedildi (Kesin alarm izni olmadığı için yaklaşık zamanda çalacaktır).',
          ),
        ),
      );
    }
  } catch (error) {
    if (context.mounted) _showReminderError(context, error);
  }
}

Future<void> editReminderEntity(
  BuildContext context,
  WidgetRef ref,
  ReminderEntity reminder,
) async {
  final notifService = ref.read(notificationServiceProvider);
  final permState = await notifService.permissionState();
  if (!context.mounted) return;
  final ReminderDraft? draft = await showReminderEditorDialog(
    context,
    existing: reminder,
    defaultTitle: reminder.title,
    defaultBody: reminder.body,
    timeZoneId: reminder.timeZoneId,
    exactAlarmsAllowed: permState.exactAlarmsAllowed,
  );
  if (draft == null) return;
  try {
    await ref
        .read(remindersRepositoryProvider)
        .update(
          id: reminder.id,
          title: draft.title,
          body: draft.body,
          scheduledAtUtc: draft.scheduledAtUtc,
          timeZoneId: draft.timeZoneId,
          enabled: draft.enabled,
        );
  } catch (error) {
    if (context.mounted) _showReminderError(context, error);
  }
}

Future<void> setReminderEnabled(
  BuildContext context,
  WidgetRef ref,
  ReminderEntity reminder,
  bool enabled,
) async {
  if (enabled && !reminder.scheduledAtUtc.isAfter(DateTime.now().toUtc())) {
    await editReminderEntity(context, ref, reminder);
    return;
  }
  try {
    await ref
        .read(remindersRepositoryProvider)
        .update(
          id: reminder.id,
          title: reminder.title,
          body: reminder.body,
          scheduledAtUtc: reminder.scheduledAtUtc,
          timeZoneId: reminder.timeZoneId,
          enabled: enabled,
        );
  } catch (error) {
    if (context.mounted) _showReminderError(context, error);
  }
}

Future<void> snoozeReminder(
  BuildContext context,
  WidgetRef ref,
  ReminderEntity reminder, {
  Duration duration = const Duration(minutes: 10),
}) async {
  final DateTime now = DateTime.now().toUtc();
  final DateTime base = reminder.scheduledAtUtc.isAfter(now)
      ? reminder.scheduledAtUtc
      : now;
  try {
    await ref
        .read(remindersRepositoryProvider)
        .update(
          id: reminder.id,
          title: reminder.title,
          body: reminder.body,
          scheduledAtUtc: base.add(duration),
          timeZoneId: reminder.timeZoneId,
          enabled: true,
        );
  } catch (error) {
    if (context.mounted) _showReminderError(context, error);
  }
}

class ReminderList extends ConsumerWidget {
  const ReminderList({
    super.key,
    required this.parentType,
    required this.parentId,
    this.emptyText = 'Hatırlatıcı yok.',
  });

  final String parentType;
  final String parentId;
  final String emptyText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(remindersRepositoryProvider);
    return StreamBuilder<List<ReminderEntity>>(
      stream: repo.watchForParent(parentType, parentId),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Text(snapshot.error.toString());
        final List<ReminderEntity> data =
            snapshot.data ?? const <ReminderEntity>[];
        if (data.isEmpty) return Text(emptyText);
        return Column(
          children: data
              .map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    item.enabled
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                  ),
                  title: Text(item.title),
                  subtitle: Text(_reminderSubtitle(context, item)),
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
                            PopupMenuItem(value: 'delete', child: Text('Sil')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

String reminderSubtitle(BuildContext context, ReminderEntity reminder) =>
    _reminderSubtitle(context, reminder);

String _reminderSubtitle(BuildContext context, ReminderEntity reminder) {
  final DateTime local = reminder.scheduledAtUtc.toLocal();
  final String date = MaterialLocalizations.of(context).formatFullDate(local);
  final String time = TimeOfDay.fromDateTime(local).format(context);
  final String state = reminder.enabled
      ? switch (reminder.schedulingStatus) {
          'scheduled' => 'kesin planlandı',
          'inexact' => 'yaklaşık planlandı',
          'failed' => 'başarısız',
          _ => reminder.schedulingStatus,
        }
      : 'devre dışı';
  return '$date · $time · $state';
}

void _showReminderError(BuildContext context, Object error) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(error.toString())));
}
