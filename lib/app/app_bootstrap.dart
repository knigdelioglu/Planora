import 'package:not_app/app/app_services.dart';
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
import 'package:not_app/features/attachments/data/repositories/attachments_repository_impl.dart';
import 'package:not_app/features/conflicts/data/repositories/conflict_repository_impl.dart';
import 'package:not_app/features/conflicts/domain/repositories/conflict_repository.dart';
import 'package:not_app/features/kanban/data/repositories/kanban_repository_impl.dart';
import 'package:not_app/features/kanban/data/repositories/lifecycle_kanban_repository.dart';
import 'package:not_app/features/kanban/domain/repositories/kanban_repository.dart';
import 'package:not_app/features/notes/data/repositories/notes_repository_impl.dart';
import 'package:not_app/features/notes/domain/repositories/notes_repository.dart';
import 'package:not_app/features/reminders/data/repositories/reminders_repository_impl.dart';
import 'package:not_app/features/reminders/domain/repositories/reminders_repository.dart';
import 'package:not_app/features/search/data/repositories/search_repository_impl.dart';
import 'package:not_app/features/search/domain/repositories/search_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class AppBootstrap {
  const AppBootstrap._();

  static Future<AppServices> create() async {
    final AppConfig config = AppConfig.fromEnvironment();
    const AppClock clock = SystemClock();
    const AppLogger logger = AppLogger();
    final AppDatabase database = await AppDatabase.open();
    try {
      final LocalNotificationService notifications = LocalNotificationService();
      await notifications.initialize();

      AuthService auth;
      RemoteGateway remote;
      if (config.cloudConfigured) {
        await Supabase.initialize(
          url: config.supabaseUrl,
          publishableKey: config.supabasePublishableKey,
        );
        final SupabaseClient client = Supabase.instance.client;
        auth = SupabaseAuthService(client);
        remote = SupabaseRemoteGateway(client);
      } else {
        auth = const DisabledAuthService();
        remote = const DisabledRemoteGateway();
      }

      final NetworkInfo network = ConnectivityNetworkInfo();
      final FileStorageService storage = SandboxFileStorageService();
      final FilePickerService picker = PlatformFilePickerService();
      final SyncQueueRepository queue = DriftSyncQueueRepository(
        database: database,
        clock: clock,
      );
      final LocalEntityStore localStore = LocalEntityStore(
        database: database,
        clock: clock,
      );
      final ConflictRepository conflicts = DriftConflictRepository(
        database: database,
        syncQueue: queue,
        localStore: localStore,
        clock: clock,
      );
      final SyncEngine engine = SyncEngine(
        database: database,
        queue: queue,
        remote: remote,
        localStore: localStore,
        conflicts: conflicts,
        clock: clock,
        logger: logger,
      );
      final AppSettingsRepository settings = DriftAppSettingsRepository(
        database,
        clock,
      );
      final NotesRepository notes = DriftNotesRepository(
        database: database,
        syncQueue: queue,
        clock: clock,
      );
      final DriftAttachmentsRepository attachments = DriftAttachmentsRepository(
        database: database,
        storage: storage,
        syncQueue: queue,
        clock: clock,
        remote: remote,
      );
      final RemindersRepository reminders = DriftRemindersRepository(
        database: database,
        notifications: notifications,
        syncQueue: queue,
        clock: clock,
      );
      final KanbanRepository kanban = LifecycleKanbanRepository(
        delegate: DriftKanbanRepository(
          database: database,
          syncQueue: queue,
          clock: clock,
        ),
        attachments: attachments,
        reminders: reminders,
      );
      final SearchRepository search = DriftSearchRepository(database);
      final SyncCoordinator coordinator = SyncCoordinator(
        networkInfo: network,
        authService: auth,
        engine: engine,
        database: database,
        clock: clock,
        reconcileReminders: reminders.reconcile,
        logger: logger,
      );
      await reminders.reconcile();
      await attachments.reconcile();
      await coordinator.start();

      return AppServices(
        config: config,
        database: database,
        clock: clock,
        logger: logger,
        networkInfo: network,
        fileStorage: storage,
        filePicker: picker,
        notifications: notifications,
        auth: auth,
        remote: remote,
        syncQueue: queue,
        localEntityStore: localStore,
        conflicts: conflicts,
        syncEngine: engine,
        syncCoordinator: coordinator,
        settings: settings,
        notes: notes,
        kanban: kanban,
        attachments: attachments,
        reminders: reminders,
        search: search,
      );
    } catch (_) {
      await database.close();
      rethrow;
    }
  }
}
