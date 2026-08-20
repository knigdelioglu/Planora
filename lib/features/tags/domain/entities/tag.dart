enum TagTargetType {
  note('note'),
  card('card');

  const TagTargetType(this.wireName);
  final String wireName;

  static TagTargetType parse(String value) => TagTargetType.values.firstWhere(
    (TagTargetType type) => type.wireName == value,
    orElse: () => throw ArgumentError.value(value, 'value', 'Unknown tag target'),
  );
}

final class TagEntity {
  const TagEntity({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.colorKey,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    this.deletedAt,
  });

  final String id;
  final String name;
  final String normalizedName;
  final String colorKey;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
}

final class TagAssignmentEntity {
  const TagAssignmentEntity({
    required this.id,
    required this.tagId,
    required this.targetType,
    required this.targetId,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    this.deletedAt,
  });

  final String id;
  final String tagId;
  final TagTargetType targetType;
  final String targetId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
}
