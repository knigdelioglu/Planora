import 'package:not_app/core/auth/auth_service.dart';
import 'package:not_app/core/config/app_config.dart';
import 'package:not_app/core/database/app_database.dart';
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

final class AppServices {
  AppServices({
    required this.config,
    required this.database,
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
  });

  final AppConfig config;
  final AppDatabase database;
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

  Future<void> dispose() async {
    await syncCoordinator.stop();
    await database.close();
  }
}
