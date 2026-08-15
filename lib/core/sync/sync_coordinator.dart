import 'dart:async';

import 'package:not_app/core/auth/auth_service.dart';
import 'package:not_app/core/logging/app_logger.dart';
import 'package:not_app/core/network/network_info.dart';
import 'package:not_app/core/sync/sync_engine.dart';

final class SyncCoordinator {
  SyncCoordinator({
    required NetworkInfo networkInfo,
    required AuthService authService,
    required SyncEngine engine,
    required AppLogger logger,
  })  : _networkInfo = networkInfo,
        _authService = authService,
        _engine = engine,
        _logger = logger;

  final NetworkInfo _networkInfo;
  final AuthService _authService;
  final SyncEngine _engine;
  final AppLogger _logger;
  StreamSubscription<bool>? _networkSubscription;
  StreamSubscription<AuthSessionState>? _authSubscription;
  Timer? _periodic;

  Future<void> start() async {
    await stop();
    _networkSubscription = _networkInfo.onConnectivityChanged.listen((connected) {
      if (connected) unawaited(syncNow());
    });
    _authSubscription = _authService.watchState().listen((state) {
      if (state.isSignedIn) unawaited(syncNow());
    });
    _periodic = Timer.periodic(const Duration(minutes: 5), (_) => unawaited(syncNow()));
    if (await _networkInfo.isConnected() && _authService.currentState.isSignedIn) {
      unawaited(syncNow());
    }
  }

  Future<SyncRunResult> syncNow() async {
    if (!_authService.currentState.isSignedIn || !await _networkInfo.isConnected()) {
      return const SyncRunResult(pushed: 0, pulled: 0, conflicts: 0);
    }
    try {
      return await _engine.runOnce();
    } catch (error, stackTrace) {
      _logger.warning('Synchronization cycle failed.', error, stackTrace);
      return const SyncRunResult(pushed: 0, pulled: 0, conflicts: 0);
    }
  }

  Future<void> stop() async {
    _periodic?.cancel();
    _periodic = null;
    await _networkSubscription?.cancel();
    await _authSubscription?.cancel();
    _networkSubscription = null;
    _authSubscription = null;
  }
}
