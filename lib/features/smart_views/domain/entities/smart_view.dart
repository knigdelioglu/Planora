import 'package:not_app/features/smart_views/domain/entities/content_filter.dart';

final class SmartViewEntity {
  const SmartViewEntity({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.rankKey,
    required this.filter,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    this.deletedAt,
  });

  final String id;
  final String name;
  final String iconKey;
  final String rankKey;
  final ContentFilter filter;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
}
