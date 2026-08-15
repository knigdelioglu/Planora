import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/app_services.dart';
import 'package:not_app/core/auth/auth_service.dart';
import 'package:not_app/core/services/file_picker_service.dart';
import 'package:not_app/core/services/notification_service.dart';
import 'package:not_app/core/settings/app_settings_repository.dart';
import 'package:not_app/core/sync/sync_coordinator.dart';
import 'package:not_app/core/sync/sync_queue_repository.dart';
import 'package:not_app/features/attachments/domain/repositories/attachments_repository.dart';
import 'package:not_app/features/conflicts/domain/repositories/conflict_repository.dart';
import 'package:not_app/features/kanban/domain/repositories/kanban_repository.dart';
import 'package:not_app/features/notes/domain/repositories/notes_repository.dart';
import 'package:not_app/features/reminders/domain/repositories/reminders_repository.dart';
import 'package:not_app/features/search/domain/repositories/search_repository.dart';

final class AppServiceRegistry {
  const AppServiceRegistry._();
  static AppServices? _current;
  static AppServices get current {
    final AppServices? value = _current;
    if (value == null) throw StateError('App services were accessed before bootstrap completed.');
    return value;
  }
  static set current(AppServices services) => _current = services;
  static void clear() => _current = null;
}

final Provider<AppServices> appServicesProvider = Provider<AppServices>((ref) => AppServiceRegistry.current);
final notesRepositoryProvider = Provider<NotesRepository>((ref) => ref.watch(appServicesProvider).notes);
final kanbanRepositoryProvider = Provider<KanbanRepository>((ref) => ref.watch(appServicesProvider).kanban);
final attachmentsRepositoryProvider = Provider<AttachmentsRepository>((ref) => ref.watch(appServicesProvider).attachments);
final remindersRepositoryProvider = Provider<RemindersRepository>((ref) => ref.watch(appServicesProvider).reminders);
final searchRepositoryProvider = Provider<SearchRepository>((ref) => ref.watch(appServicesProvider).search);
final conflictRepositoryProvider = Provider<ConflictRepository>((ref) => ref.watch(appServicesProvider).conflicts);
final authServiceProvider = Provider<AuthService>((ref) => ref.watch(appServicesProvider).auth);
final notificationServiceProvider = Provider<NotificationService>((ref) => ref.watch(appServicesProvider).notifications);
final filePickerServiceProvider = Provider<FilePickerService>((ref) => ref.watch(appServicesProvider).filePicker);
final syncCoordinatorProvider = Provider<SyncCoordinator>((ref) => ref.watch(appServicesProvider).syncCoordinator);
final syncQueueRepositoryProvider = Provider<SyncQueueRepository>((ref) => ref.watch(appServicesProvider).syncQueue);
final settingsRepositoryProvider = Provider<AppSettingsRepository>((ref) => ref.watch(appServicesProvider).settings);
