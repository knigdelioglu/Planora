import 'package:connectivity_plus/connectivity_plus.dart';

abstract interface class NetworkInfo {
  Future<bool> get hasNetworkInterface;
  Stream<bool> get onNetworkInterfaceChanged;
}

final class ConnectivityNetworkInfo implements NetworkInfo {
  ConnectivityNetworkInfo(this._connectivity);

  final Connectivity _connectivity;

  @override
  Future<bool> get hasNetworkInterface async {
    final result = await _connectivity.checkConnectivity();
    return result.any((value) => value != ConnectivityResult.none);
  }

  @override
  Stream<bool> get onNetworkInterfaceChanged => _connectivity.onConnectivityChanged
      .map((results) => results.any((value) => value != ConnectivityResult.none))
      .distinct();
}
