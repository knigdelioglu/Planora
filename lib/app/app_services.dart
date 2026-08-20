import 'package:not_app/core/auth/auth_service.dart';
import 'package:not_app/core/config/app_config.dart';
import 'package:not_app/core/database/app_database.dart';
import 'package:not_app/core/events/entity_change_bus.dart';
import 'package:not_app/core/logging/app_logger.dart';
import 'package:not_app/core/network/network_info.dart';
import 'package:not_app/core/remote/remote_gateway.dart';
import 'package:not_app/core/services/file_picker_service.dart';
import 'package:not_app/core/services/file_storage_service.dart';
import 'package:not_app/core/services/notification_service.dart';
import 'package:not_app/core/settings/app_settings_repository.dart';
import 'package:not_app/core/sync/local_entity_store.dart';
import 'package:not_app/core/sync/sync_coordinator.dart';
import 'package:not_app/core/sync/sync_engine.dart';
import 'package:not_app/core/sync/sync_queue_repository.dart';
import 'package:not_app/core/utils/clock.dart';
import 'package:not_app/features/attachments/domain/repositories/attachments_repository.dart';
import 'package:not_app/features/conflicts/domain/repositories/conflict_repository.dart';
import 'package:not_app/features/kanban/domain/repositories/kanban_repository.dart';
import 'package:not_app/features/notes/domain/repositories/note_kanban_repository.dart';
import 'package:not_app/features/notes/domain/repositories/notes_repository.dart';
import 'package:not_app/features/reminders/domain/repositories/reminders_repository.dart';
import 'package:not_app/features/search/domain/repositories/search_repository.dart';
import 'package:not_app/features/smart_views/domain/entities/content_filter.dart';
import 'package:not_app/features/smart_views/domain/entities/smart_view.dart';
import 'package:not_app/features/smart_views/domain/entities/smart_view_result.dart';
import 'package:not_app/features/smart_views/domain/repositories/smart_views_repository.dart';
import 'package:not_app/features/tags/domain/entities/tag.dart';
import 'package:not_app/features/tags/domain/repositories/tags_repository.dart';

final class AppServices {
  AppServices({
    required this.config,
    required this.database,
    EntityChangeBus? changeBus,
    required this.clock,
    required this.logger,
    required this.networkInfo,
    required this.fileStorage,
    required this.filePicker,
    required this.notifications,
    required this.auth,
    required this.remote,
    required this.syncQueue,
    required this.localEntityStore,
    required this.conflicts,
    required this.syncEngine,
    required this.syncCoordinator,
    required this.settings,
    required this.notes,
    required this.kanban,
    required this.noteKanban,
    required this.attachments,
    required this.reminders,
    required this.search,
    TagsRepository? tags,
    SmartViewsRepository? smartViews,
  }) : changeBus = changeBus ?? EntityChangeBus(),
       tags = tags ?? const _EmptyTagsRepository(),
       smartViews = smartViews ?? const _EmptySmartViewsRepository();

  final AppConfig config;
  final AppDatabase database;
  final EntityChangeBus changeBus;
  final AppClock clock;
  final AppLogger logger;
  final NetworkInfo networkInfo;
  final FileStorageService fileStorage;
  final FilePickerService filePicker;
  final NotificationService notifications;
  final AuthService auth;
  final RemoteGateway remote;
  final SyncQueueRepository syncQueue;
  final LocalEntityStore localEntityStore;
  final ConflictRepository conflicts;
  final SyncEngine syncEngine;
  final SyncCoordinator syncCoordinator;
  final AppSettingsRepository settings;
  final NotesRepository notes;
  final KanbanRepository kanban;
  final NoteKanbanRepository noteKanban;
  final AttachmentsRepository attachments;
  final RemindersRepository reminders;
  final SearchRepository search;
  final TagsRepository tags;
  final SmartViewsRepository smartViews;

  Future<void> dispose() async {
    await syncCoordinator.stop();
    await changeBus.dispose();
    await database.close();
  }
}

/// Keeps legacy widget/performance fixtures focused on their original feature.
/// Production bootstrap always supplies the real repository.
final class _EmptyTagsRepository implements TagsRepository {
  const _EmptyTagsRepository();

  @override
  Stream<List<TagEntity>> watchTags() => Stream.value(const <TagEntity>[]);

  @override
  Stream<List<TagEntity>> watchTagsForTarget({
    required TagTargetType targetType,
    required String targetId,
  }) => Stream.value(const <TagEntity>[]);

  @override
  Stream<int> watchUsageCount(String tagId) => Stream.value(0);

  @override
  Future<List<TagEntity>> tagsForTarget({
    required TagTargetType targetType,
    required String targetId,
  }) async => const <TagEntity>[];

  @override
  Future<String> createTag({
    required String name,
    String colorKey = 'indigo',
  }) => Future<String>.error(
    StateError('TagsRepository is not installed in this fixture.'),
  );

  @override
  Future<void> renameTag(String tagId, String name) async {}

  @override
  Future<void> setColor(String tagId, String colorKey) async {}

  @override
  Future<void> deleteTag(String tagId) async {}

  @override
  Future<void> assign({
    required String tagId,
    required TagTargetType targetType,
    required String targetId,
  }) async {}

  @override
  Future<void> unassign({
    required String tagId,
    required TagTargetType targetType,
    required String targetId,
  }) async {}

  @override
  Future<void> deleteAssignmentsForTarget({
    required TagTargetType targetType,
    required String targetId,
  }) async {}
}

final class _EmptySmartViewsRepository implements SmartViewsRepository {
  const _EmptySmartViewsRepository();

  @override
  Stream<List<SmartViewEntity>> watchViews() =>
      Stream.value(const <SmartViewEntity>[]);

  @override
  Stream<List<SmartViewResult>> watchResults(ContentFilter filter) =>
      Stream.value(const <SmartViewResult>[]);

  @override
  Future<List<SmartViewResult>> query(ContentFilter filter) async =>
      const <SmartViewResult>[];

  @override
  Future<String> createView({
    required String name,
    required ContentFilter filter,
    String iconKey = 'filter_alt',
  }) => Future<String>.error(
    StateError('SmartViewsRepository is not installed in this fixture.'),
  );

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
