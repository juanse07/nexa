import 'package:connectivity_plus/connectivity_plus.dart';

/// Abstract class for network connectivity information
abstract class NetworkInfo {
  /// Checks if the device is connected to the internet
  Future<bool> get isConnected;

  /// Stream of connectivity changes
  Stream<bool> get onConnectivityChanged;
}

/// Implementation of [NetworkInfo] using connectivity_plus package
class NetworkInfoImpl implements NetworkInfo {
  /// Creates a [NetworkInfoImpl] with a connectivity instance
  NetworkInfoImpl(this._connectivity);

  final Connectivity _connectivity;

  @override
  Future<bool> get isConnected async {
    final result = await _connectivity.checkConnectivity();
    return _isConnected(result);
  }

  @override
  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map(_isConnected);
  }

  /// Checks if the connectivity result indicates a connection
  bool _isConnected(List<ConnectivityResult> result) {
    return result.isNotEmpty &&
        !result.contains(ConnectivityResult.none) &&
        (result.contains(ConnectivityResult.mobile) ||
            result.contains(ConnectivityResult.wifi) ||
            result.contains(ConnectivityResult.ethernet) ||
            result.contains(ConnectivityResult.vpn));
  }
}
