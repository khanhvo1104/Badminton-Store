import 'package:connectivity_plus/connectivity_plus.dart';

abstract interface class NetworkInfo {
  Future<bool> get isConnected;
}

class NetworkInfoImpl implements NetworkInfo {
  NetworkInfoImpl({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }
}

class FakeNetworkInfo implements NetworkInfo {
  FakeNetworkInfo({this.isConnectedValue = true});

  bool isConnectedValue;

  @override
  Future<bool> get isConnected async => isConnectedValue;
}
