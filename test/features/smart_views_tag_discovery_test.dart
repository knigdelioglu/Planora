import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/features/smart_views/domain/entities/content_filter.dart';
import 'package:not_app/features/smart_views/domain/entities/smart_view.dart';
import 'package:not_app/features/smart_views/domain/entities/smart_view_result.dart';
import 'package:not_app/features/smart_views/domain/repositories/smart_views_repository.dart';
import 'package:not_app/features/smart_views/presentation/screens/smart_views_screen.dart';
import 'package:not_app/features/tags/domain/entities/tag.dart';
import 'package:not_app/features/tags/domain/repositories/tags_repository.dart';

void main() {
  testWidgets('created tags automatically become filterable smart views', (
    WidgetTester tester,
  ) async {
    final _FakeTagsRepository tags = _FakeTagsRepository(<TagEntity>[_tag]);
    final _FakeSmartViewsRepository smartViews = _FakeSmartViewsRepository();
    addTearDown(tags.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagsRepositoryProvider.overrideWithValue(tags),
          smartViewsRepositoryProvider.overrideWithValue(smartViews),
        ],
        child: const MaterialApp(home: SmartViewsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ETİKETLER'), findsOneWidget);
    expect(find.text('Okul'), findsOneWidget);

    await tester.tap(find.text('Okul'));
    await tester.pumpAndSettle();

    expect(smartViews.lastFilter?.anyTagIds, <String>['tag-1']);
  });

  testWidgets('tag can be deleted directly from smart views', (
    WidgetTester tester,
  ) async {
    final _FakeTagsRepository tags = _FakeTagsRepository(<TagEntity>[_tag]);
    final _FakeSmartViewsRepository smartViews = _FakeSmartViewsRepository();
    addTearDown(tags.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagsRepositoryProvider.overrideWithValue(tags),
          smartViewsRepositoryProvider.overrideWithValue(smartViews),
        ],
        child: const MaterialApp(home: SmartViewsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('smart-view-tag-menu-tag-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Etiketi sil'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
    await tester.pumpAndSettle();

    expect(tags.deletedIds, <String>['tag-1']);
    expect(find.text('Okul'), findsNothing);
  });
}

final TagEntity _tag = TagEntity(
  id: 'tag-1',
  name: 'Okul',
  normalizedName: 'okul',
  colorKey: 'indigo',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  version: 1,
);

final class _FakeSmartViewsRepository implements SmartViewsRepository {
  ContentFilter? lastFilter;

  @override
  Stream<List<SmartViewEntity>> watchViews() =>
      Stream<List<SmartViewEntity>>.value(const <SmartViewEntity>[]);

  @override
  Stream<List<SmartViewResult>> watchResults(ContentFilter filter) {
    lastFilter = filter;
    return Stream<List<SmartViewResult>>.value(const <SmartViewResult>[]);
  }

  @override
  Future<List<SmartViewResult>> query(ContentFilter filter) async {
    lastFilter = filter;
    return const <SmartViewResult>[];
  }

  @override
  Future<String> createView({
    required String name,
    required ContentFilter filter,
    String iconKey = 'filter_alt',
  }) async => 'view-1';

  @override
  Future<void> updateView({
    required String viewId,
    required String name,
    required ContentFilter filter,
    String? iconKey,
  }) async {}

  @override
  Future<void> deleteView(String viewId) async {}
}

final class _FakeTagsRepository implements TagsRepository {
  _FakeTagsRepository(List<TagEntity> tags) : _tags = List<TagEntity>.of(tags);

  final StreamController<List<TagEntity>> _changes =
      StreamController<List<TagEntity>>.broadcast(sync: true);
  List<TagEntity> _tags;
  final List<String> deletedIds = <String>[];

  @override
  Stream<List<TagEntity>> watchTags() async* {
    yield List<TagEntity>.unmodifiable(_tags);
    yield* _changes.stream;
  }

  @override
  Future<void> deleteTag(String tagId) async {
    deletedIds.add(tagId);
    _tags = _tags.where((TagEntity tag) => tag.id != tagId).toList();
    _changes.add(List<TagEntity>.unmodifiable(_tags));
  }

  Future<void> dispose() => _changes.close();

  @override
  Stream<List<TagEntity>> watchTagsForTarget({
    required TagTargetType targetType,
    required String targetId,
  }) => Stream<List<TagEntity>>.value(const <TagEntity>[]);

  @override
  Stream<int> watchUsageCount(String tagId) => Stream<int>.value(0);

  @override
  Future<List<TagEntity>> tagsForTarget({
    required TagTargetType targetType,
    required String targetId,
  }) async => const <TagEntity>[];

  @override
  Future<String> createTag({
    required String name,
    String colorKey = 'indigo',
  }) => throw UnimplementedError();

  @override
  Future<void> renameTag(String tagId, String name) =>
      throw UnimplementedError();

  @override
  Future<void> setColor(String tagId, String colorKey) =>
      throw UnimplementedError();

  @override
  Future<void> assign({
    required String tagId,
    required TagTargetType targetType,
    required String targetId,
  }) => throw UnimplementedError();

  @override
  Future<void> unassign({
    required String tagId,
    required TagTargetType targetType,
    required String targetId,
  }) => throw UnimplementedError();

  @override
  Future<void> deleteAssignmentsForTarget({
    required TagTargetType targetType,
    required String targetId,
  }) => throw UnimplementedError();
}
