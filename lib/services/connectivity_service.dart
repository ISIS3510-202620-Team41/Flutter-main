
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance =
      ConnectivityService._();

  final Connectivity _connectivity = Connectivity();

  final StreamController<bool> _controller =
      StreamController<bool>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool? _isOnline;

  bool? get isOnline => _isOnline;

  Stream<bool> get onConnectivityChanged =>
      _controller.stream;

  Future<void> start() async {
    if (_subscription != null) return;

    _subscription = _connectivity.onConnectivityChanged.listen(
      _updateStatus,
      onError: (Object error) {
        // La comprobación posterior de conectividad permitirá recuperar el estado.
      },
    );

    await refresh();
  }

  Future<void> refresh() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateStatus(results);
    } catch (_) {
      // No modificamos el último estado conocido si falla
    }
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final connected = results.any(
      (result) => result != ConnectivityResult.none,
    );

    if (_isOnline == connected) return;

    _isOnline = connected;

    if (!_controller.isClosed) {
      _controller.add(connected);
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;

    await _controller.close();
  }
}
