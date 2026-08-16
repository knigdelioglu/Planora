import 'dart:async';

import 'package:not_app/core/auth/auth_service.dart';
import 'package:not_app/core/database/app_database.dart';
import 'package:not_app/core/logging/app_logger.dart';
import 'package:not_app/core/network/network_info.dart';
import 'package:not_app/core/sync/sync_engine.dart';
import 'package:not_app/core/utils/clock.dart';

final class SyncHealthState {
  const SyncHealthState({
    this.isSyncing = false,
    this.isOnline,
    this.lastSuccessfulSyncAt,
    this.lastError,
  });

  final bool isSyncing;
  final bool? isOnline;
  final DateTime? lastSuccessfulSyncAt;
  final String? lastError;
}

final class SyncCoordinator {
  SyncCoordinator({
    required this._networkInfo,
    required this._authService,
    required this._engine,
    required this._database,
    required this._clock,
    required this._reconcileReminders,
    required this._logger,
  });

  static const String _lastSuccessKey = 'last_successful_sync_at';
  static const String _lastErrorKey = 'last_sync_error';

  final NetworkInfo _networkInfo;
  final AuthService _authService;
  final SyncEngine _engine;
  final AppDatabase _database;
  final AppClock _clock;
  final Future<void> Function() _reconcileReminders;
  final AppLogger _logger;
  final StreamController<SyncHealthState> _healthController =
      StreamController<SyncHealthState>.broadcast();

  StreamSubscription<bool>? _networkSubscription;
  StreamSubscription<AuthSessionState>? _authSubscription;
  Timer? _periodic;
  Completer<SyncRunResult>? _inFlight;
  bool _pendingFollowUp = false;
  SyncHealthState _health = const SyncHealthState();

  SyncHealthState get currentHealth => _health;

  Stream<SyncHealthState> watchHealth() async* {
    yield _health;
    yield* _healthController.stream;
  }

  Future<void> start() async {
    await stop();
    await _loadHealth();
    _networkSubscription = _networkInfo.onConnectivityChanged.listen((
      connected,
    ) {
      _setHealth(
        SyncHealthState(
          isSyncing: _health.isSyncing,
          isOnline: connected,
          lastSuccessfulSyncAt: _health.lastSuccessfulSyncAt,
          lastError: _health.lastError,
        ),
      );
      if (connected) unawaited(syncNow());
    });
    _authSubscription = _authService.watchState().listen((state) {
      if (state.isSignedIn) unawaited(syncNow());
    });
    _periodic = Timer.periodic(
      const Duration(minutes: 5),
      (_) => unawaited(syncNow()),
    );
    final bool connected = await _networkInfo.isConnected();
    _setHealth(
      SyncHealthState(
        isOnline: connected,
        lastSuccessfulSyncAt: _health.lastSuccessfulSyncAt,
        lastError: _health.lastError,
      ),
    );
    if (connected && _authService.currentState.isSignedIn) {
      unawaited(syncNow());
    }
  }

  Future<SyncRunResult> syncNow() async {
    if (!_authService.currentState.isSignedIn) {
      return const SyncRunResult(pushed: 0, pulled: 0, conflicts: 0);
    }
    if (_inFlight != null) {
      _pendingFollowUp = true;
      return _inFlight!.future;
    }
    final Completer<SyncRunResult> completer = Completer<SyncRunResult>();
    _inFlight = completer;
    try {
      int totalPushed = 0;
      int totalPulled = 0;
      int totalConflicts = 0;

      while (true) {
        _pendingFollowUp = false;
        if (!await _networkInfo.isConnected()) {
          _setHealth(
            SyncHealthState(
              isOnline: false,
              lastSuccessfulSyncAt: _health.lastSuccessfulSyncAt,
              lastError: _health.lastError,
            ),
          );
          break;
        }
        _setHealth(
          SyncHealthState(
            isSyncing: true,
            isOnline: true,
            lastSuccessfulSyncAt: _health.lastSuccessfulSyncAt,
          ),
        );
        final SyncRunResult result = await _engine.runOnce();
        await _reconcileReminders();
        totalPushed += result.pushed;
        totalPulled += result.pulled;
        totalConflicts += result.conflicts;
        final DateTime successAt = _clock.nowUtc();
        await _writeMeta(_lastSuccessKey, successAt.toIso8601String());
        await _deleteMeta(_lastErrorKey);
        _setHealth(
          SyncHealthState(isOnline: true, lastSuccessfulSyncAt: successAt),
        );
        if (!_pendingFollowUp) break;
      }

      final SyncRunResult combined = SyncRunResult(
        pushed: totalPushed,
        pulled: totalPulled,
        conflicts: totalConflicts,
      );
      completer.complete(combined);
      return combined;
    } catch (error, stackTrace) {
      final String safeError = _safeError(error);
      await _writeMeta(_lastErrorKey, safeError);
      _setHealth(
        SyncHealthState(
          isOnline: true,
          lastSuccessfulSyncAt: _health.lastSuccessfulSyncAt,
          lastError: safeError,
        ),
      );
      _logger.warning('Synchronization cycle failed.', error, stackTrace);
      const SyncRunResult failResult = SyncRunResult(
        pushed: 0,
        pulled: 0,
        conflicts: 0,
      );
      completer.complete(failResult);
      return failResult;
    } finally {
      _inFlight = null;
    }
  }

  Future<void> stop() async {
    _periodic?.cancel();
    _periodic = null;
    await _networkSubscription?.cancel();
    await _authSubscription?.cancel();
    _networkSubscription = null;
    _authSubscription = null;
    if (_inFlight != null) {
      try {
        await _inFlight!.future;
      } catch (_) {}
    }
  }

  Future<void> _loadHealth() async {
    final String? successRaw = await _readMeta(_lastSuccessKey);
    final String? error = await _readMeta(_lastErrorKey);
    _setHealth(
      SyncHealthState(
        isOnline: _health.isOnline,
        lastSuccessfulSyncAt: successRaw == null
            ? null
            : DateTime.tryParse(successRaw)?.toUtc(),
        lastError: error,
      ),
    );
  }

  void _setHealth(SyncHealthState value) {
    _health = value;
    _healthController.add(value);
  }

  Future<String?> _readMeta(String key) async {
    final SyncMetaData? row = await (_database.select(
      _database.syncMeta,
    )..where((tbl) => tbl.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _writeMeta(String key, String value) async {
    await _database
        .into(_database.syncMeta)
        .insertOnConflictUpdate(
          SyncMetaCompanion.insert(
            key: key,
            value: value,
            updatedAt: _clock.nowUtc(),
          ),
        );
  }

  Future<void> _deleteMeta(String key) async {
    await (_database.delete(
      _database.syncMeta,
    )..where((tbl) => tbl.key.equals(key))).go();
  }

  String _safeError(Object error) {
    final String value = error.toString();
    return value.length <= 500 ? value : value.substring(0, 500);
  }
}
