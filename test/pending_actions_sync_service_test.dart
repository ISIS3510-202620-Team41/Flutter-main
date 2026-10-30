
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:llamalla/analytics/analytics_facade.dart';
import 'package:llamalla/analytics/analytics_feature_catalog.dart';
import 'package:llamalla/database/app_database.dart';
import 'package:llamalla/models/pending_action.dart';
import 'package:llamalla/repositories/pending_actions_repository.dart';
import 'package:llamalla/services/auth_service.dart';
import 'package:llamalla/services/connectivity_service.dart';
import 'package:llamalla/services/pending_actions_sync_service.dart';

class _FakeConnectivityService implements ConnectivityService {
  _FakeConnectivityService(this.isOnline);

  @override
  bool? isOnline;

  final StreamController<bool> _controller =
      StreamController<bool>.broadcast();

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  void emit(bool online) {
    isOnline = online;
    _controller.add(online);
  }

  @override
  Future<void> start() async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

class _TestAuthService extends AuthService {
  String userId = 'user-1';

  int userIdCalls = 0;

  Completer<void>? userIdGate;

  http.Response response = http.Response('', 200);

  Object? requestError;

  final List<String> requestedMethods = [];
  final List<String> requestedPaths = [];

  @override
  Future<String?> getCurrentUserId() async {
    userIdCalls++;

    final gate = userIdGate;

    if (gate != null) {
      await gate.future;
    }

    return userId;
  }

  @override
  Future<http.Response> authenticatedRequest({
    required String method,
    required String path,
    Map<String, String>? headers,
    Object? body,
  }) async {
    requestedMethods.add(method);
    requestedPaths.add(path);

    final error = requestError;

    if (error != null) {
      throw error;
    }

    return response;
  }
}

class _RecordingAnalyticsFacade extends AnalyticsFacade {
  _RecordingAnalyticsFacade() : super();

  final List<Map<String, String?>> featureEvents = [];

  @override
  Future<void> trackFeatureUsed({
    required String feature,
    String? action,
    String? screen,
  }) async {
    featureEvents.add({
      'feature': feature,
      'action': action,
      'screen': screen,
    });
  }
}

PendingAction _createAction({
  String id = 'action-1',
  String activityId = 'activity-1',
  Map<String, dynamic> payload = const {
    'recommendationId': 'recommendation-1',
    'freeTimeMinutes': 45,
  },
  PendingActionStatus status = PendingActionStatus.pending,
  int attempts = 0,
}) {
  return PendingAction(
    id: id,
    userId: 'user-1',
    type: PendingActionType.joinActivity,
    activityId: activityId,
    payload: payload,
    status: status,
    attempts: attempts,
    createdAt: DateTime.utc(2026, 10, 3),
    updatedAt: DateTime.utc(2026, 10, 3),
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  late AppDatabase appDatabase;
  late PendingActionsRepository repository;
  late _FakeConnectivityService connectivity;
  late _TestAuthService authService;
  late _RecordingAnalyticsFacade analytics;
  late PendingActionsSyncService syncService;

  setUp(() async {
    authSession.setUnauthenticated();

    appDatabase = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );

    final database = await appDatabase.database;

    repository = PendingActionsRepository(database);

    connectivity = _FakeConnectivityService(true);
    authService = _TestAuthService();
    analytics = _RecordingAnalyticsFacade();

    syncService = PendingActionsSyncService(
      connectivityService: connectivity,
      repository: repository,
      authService: authService,
      analyticsFacade: analytics,
    );

    authSession.setAuthenticated();
  });

  tearDown(() async {
    await connectivity.dispose();
    await appDatabase.close();
    authSession.setUnauthenticated();
  });

  test('syncs a pending join and deletes it after success', () async {
    final action = _createAction();

    await repository.enqueue(action);

    final syncedIds = <String>[];

    final subscription = syncService.onActionSynced.listen(
      (syncedAction) {
        syncedIds.add(syncedAction.id);
      },
    );

    await syncService.syncPendingActions();

    await Future<void>.delayed(Duration.zero);

    final result = await repository.getById(action.id);

    expect(result, isNull);
    expect(syncedIds, ['action-1']);

    expect(authService.requestedMethods, ['POST']);
    expect(authService.requestedPaths, hasLength(1));

    final requestUri = Uri.parse(
      authService.requestedPaths.single,
    );

    expect(requestUri.path, '/activities/activity-1/join');

    expect(
      requestUri.queryParameters,
      {
        'recommendationId': 'recommendation-1',
        'freeTimeMinutes': '45',
      },
    );

    expect(analytics.featureEvents, [
      {
        'feature': AnalyticsFeatureCatalog.activityJoining,
        'action': AnalyticsFeatureCatalog.joinRecommendedActivityAction,
        'screen': AnalyticsFeatureCatalog.activityJoiningScreen,
      },
    ]);

    await subscription.cancel();
  });

  test('keeps an action pending when the backend returns HTTP 503',
      () async {
    final action = _createAction();

    await repository.enqueue(action);

    authService.response = http.Response(
      '{"message":"Service unavailable"}',
      503,
    );

    await syncService.syncPendingActions();

    final result = await repository.getById(action.id);

    expect(result, isNotNull);
    expect(result!.status, PendingActionStatus.pending);
    expect(result.attempts, 1);
    expect(result.lastError, 'Service unavailable');
  });

  test('keeps an action pending when the request fails due to network loss',
      () async {
    final action = _createAction();

    await repository.enqueue(action);

    authService.requestError =
        http.ClientException('Connection refused');

    await syncService.syncPendingActions();

    final result = await repository.getById(action.id);

    expect(result, isNotNull);
    expect(result!.status, PendingActionStatus.pending);
    expect(result.attempts, 1);
    expect(result.lastError, contains('Connection refused'));
  });

  test('keeps an action pending when the request times out', () async {
    final action = _createAction();

    await repository.enqueue(action);

    authService.requestError = TimeoutException('Request timed out');

    await syncService.syncPendingActions();

    final result = await repository.getById(action.id);

    expect(result, isNotNull);
    expect(result!.status, PendingActionStatus.pending);
    expect(result.attempts, 1);
    expect(result.lastError, contains('Request timed out'));
  });

  test('marks an action as failed when the backend returns HTTP 404',
      () async {
    final action = _createAction();

    await repository.enqueue(action);

    authService.response = http.Response(
      '{"message":"Activity not found"}',
      404,
    );

    await syncService.syncPendingActions();

    final result = await repository.getById(action.id);

    expect(result, isNotNull);
    expect(result!.status, PendingActionStatus.failed);
    expect(result.attempts, 1);
    expect(result.lastError, 'Activity not found');
  });

  test('keeps an action pending when the session expires', () async {
    final action = _createAction();

    await repository.enqueue(action);

    authService.requestError = const SessionExpiredException();

    await syncService.syncPendingActions();

    final result = await repository.getById(action.id);

    expect(result, isNotNull);
    expect(result!.status, PendingActionStatus.pending);
    expect(result.attempts, 1);
    expect(
      result.lastError,
      contains('Tu sesión expiró'),
    );
  });

  test('does not synchronize while there is no connectivity', () async {
    final action = _createAction();

    await repository.enqueue(action);

    connectivity.isOnline = false;

    await syncService.syncPendingActions();

    final result = await repository.getById(action.id);

    expect(result, isNotNull);
    expect(result!.status, PendingActionStatus.pending);
    expect(result.attempts, 0);
    expect(authService.requestedPaths, isEmpty);
  });

  test('does not synchronize when the user is unauthenticated', () async {
    final action = _createAction();

    await repository.enqueue(action);

    authSession.setUnauthenticated();

    await syncService.syncPendingActions();

    final result = await repository.getById(action.id);

    expect(result, isNotNull);
    expect(result!.status, PendingActionStatus.pending);
    expect(result.attempts, 0);
    expect(authService.requestedPaths, isEmpty);
  });

  test('does not process the same action twice during concurrent sync calls',
      () async {
    final action = _createAction();

    await repository.enqueue(action);

    final gate = Completer<void>();
    authService.userIdGate = gate;

    final firstSync = syncService.syncPendingActions();
    final secondSync = syncService.syncPendingActions();

    gate.complete();

    await Future.wait([firstSync, secondSync]);

    final result = await repository.getById(action.id);

    expect(result, isNull);
    expect(authService.userIdCalls, 1);
    expect(authService.requestedPaths, hasLength(1));
  });
}
