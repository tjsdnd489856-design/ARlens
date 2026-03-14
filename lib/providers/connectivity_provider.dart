import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityProvider extends ChangeNotifier {
  List<ConnectivityResult> _connectionStatus = [ConnectivityResult.none];
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  bool _isOffline = false;
  bool get isOffline => _isOffline;

  ConnectivityProvider() {
    _initConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  Future<void> _initConnectivity() async {
    late List<ConnectivityResult> result;
    try {
      result = await _connectivity.checkConnectivity();
    } catch (e) {
      debugPrint('Couldn\'t check connectivity status: $e');
      return;
    }
    return _updateConnectionStatus(result);
  }

  Future<void> _updateConnectionStatus(List<ConnectivityResult> result) async {
    _connectionStatus = result;
    _isOffline = _connectionStatus.contains(ConnectivityResult.none);
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }
}
