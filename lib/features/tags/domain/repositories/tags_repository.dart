import 'package:not_app/features/tags/domain/entities/tag.dart';

abstract interface class TagsRepository {
  Stream<List<TagEntity>> watchTags();

  Stream<List<TagEntity>> watchTagsForTarget({
    required TagTargetType targetType,
    required String targetId,
  });

  Stream<int> watchUsageCount(String tagId);

  Future<List<TagEntity>> tagsForTarget({
    required TagTargetType targetType,
    required String targetId,
  });

  Future<String> createTag({required String name, String colorKey = 'indigo'});

  Future<void> renameTag(String tagId, String name);

  Future<void> setColor(String tagId, String colorKey);

  Future<void> deleteTag(String tagId);

  Future<void> assign({
    required String tagId,
    required TagTargetType targetType,
    required String targetId,
  });

  Future<void> unassign({
    required String tagId,
    required TagTargetType targetType,
    required String targetId,
  });

  Future<void> deleteAssignmentsForTarget({
    required TagTargetType targetType,
    required String targetId,
  });
}
