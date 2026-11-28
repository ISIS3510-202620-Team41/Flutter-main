import 'dart:async';

import '../repositories/activity_repository.dart';
import 'connectivity_service.dart';

class SyncService {
  SyncService({
    ConnectivityService? connectivityService,
    ActivityRepository? repository,
  }) : _connectivityService =
           connectivityService ?? ConnectivityService.instance,
       _repository = repository ?? ActivityRepository();

  static final instance = SyncService();

  final ConnectivityService _connectivityService;
  final ActivityRepository _repository;
  StreamSubscription<bool>? _subscription;

  void start() {
    _subscription ??= _connectivityService.onConnectivityChanged.listen((
      online,
    ) {
      if (online) {
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
