import 'dart:async';

import 'package:not_app/core/network/network_info.dart';

abstract interface class SyncQueueProcessor {
  Future<void> processPending();
}

final class SyncCoordinator {
  SyncCoordinator({
    required NetworkInfo networkInfo,
    required SyncQueueProcessor processor,
  })  : _networkInfo = networkInfo,
        _processor = processor;

  final NetworkInfo _networkInfo;
  final SyncQueueProcessor _processor;
  StreamSubscription<bool>? _subscription;
  bool _running = false;

  Future<void> start() async {
    _subscription ??= _networkInfo.onNetworkInterfaceChanged.listen((online) {
      if (online) unawaited(syncNow());
    });
    if (await _networkInfo.hasNetworkInterface) {
      await syncNow();
    }
  }

  Future<void> syncNow() async {
    if (_running) return;
    _running = true;
    try {
      await _processor.processPending();
    } finally {
      _running = false;
    }
  }

  Future<void> dispose() async => _subscription?.cancel();
}
