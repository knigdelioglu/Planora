final class SearchResultEntity {
  const SearchResultEntity({
    required this.entityType,
    required this.entityId,
    required this.title,
    required this.preview,
  });

  final String entityType;
  final String entityId;
  final String title;
  final String preview;
}
