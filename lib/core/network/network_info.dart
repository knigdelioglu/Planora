import 'package:connectivity_plus/connectivity_plus.dart';

abstract interface class NetworkInfo {
  Future<bool> isConnected();
  Stream<bool> get onConnectivityChanged;
}

final class ConnectivityNetworkInfo implements NetworkInfo {
  ConnectivityNetworkInfo({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();
  final Connectivity _connectivity;

  @override
  Future<bool> isConnected() async {
    final List<ConnectivityResult> results = await _connectivity
        .checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }

  @override
  Stream<bool> get onConnectivityChanged => _connectivity.onConnectivityChanged
      .map(
        (results) => results.any((result) => result != ConnectivityResult.none),
      )
      .distinct();
}
