final class SmartViewResult {
  const SmartViewResult({
    required this.entityType,
    required this.entityId,
    required this.title,
    required this.preview,
    required this.updatedAt,
    this.boardId,
    this.columnId,
    this.isFavorite = false,
    this.hasReminder = false,
    this.hasAttachment = false,
  });

  final String entityType;
  final String entityId;
  final String title;
  final String preview;
  final DateTime updatedAt;
  final String? boardId;
  final String? columnId;
  final bool isFavorite;
  final bool hasReminder;
  final bool hasAttachment;
}
