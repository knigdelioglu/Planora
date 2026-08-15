class Reminder {
  const Reminder({
    required this.id,
    required this.parentType,
    required this.parentId,
    required this.title,
    required this.scheduledAtUtc,
    required this.timeZoneId,
    required this.notificationId,
    required this.enabled,
  });

  final String id;
  final String parentType;
  final String parentId;
  final String title;
  final DateTime scheduledAtUtc;
  final String timeZoneId;
  final int notificationId;
  final bool enabled;
}
