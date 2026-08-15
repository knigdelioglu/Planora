final class ReminderEntity {
  const ReminderEntity({
    required this.id,
    required this.parentType,
    required this.parentId,
    required this.title,
    required this.scheduledAtUtc,
    required this.timeZoneId,
    required this.notificationId,
    required this.enabled,
    required this.schedulingStatus,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    this.body,
    this.lastReconciledAt,
    this.deletedAt,
  });

  final String id;
  final String parentType;
  final String parentId;
  final String title;
  final String? body;
  final DateTime scheduledAtUtc;
  final String timeZoneId;
  final int notificationId;
  final bool enabled;
  final String schedulingStatus;
  final DateTime? lastReconciledAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final DateTime? deletedAt;
}
