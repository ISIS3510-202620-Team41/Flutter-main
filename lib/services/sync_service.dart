import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../repositories/activity_repository.dart';

class SyncService {
  SyncService._();

  static final instance = SyncService._();

  final _repository = ActivityRepository();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  void start() {
    _subscription ??= Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        unawaited(_repository.syncPending());
      }
    });
    unawaited(_repository.syncPending());
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}