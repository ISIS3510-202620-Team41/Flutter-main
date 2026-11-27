import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:llamalla/database/app_database.dart';
import 'package:llamalla/models/activity_record.dart';
import 'package:llamalla/models/joined_activity_record.dart';
import 'package:llamalla/models/pending_action.dart';
import 'package:llamalla/repositories/activity_local_repository.dart';
import 'package:llamalla/repositories/joined_activities_repository.dart';
import 'package:llamalla/repositories/pending_actions_repository.dart';
import 'package:llamalla/services/activity_service.dart';
import 'package:llamalla/services/auth_service.dart';
import 'package:llamalla/services/connectivity_service.dart';
import 'package:llamalla/services/pending_actions_sync_service.dart';
import 'package:llamalla/services/storage_capacity_service.dart';
import 'package:llamalla/viewmodels/joined_activities_view_model.dart';

class _FakeConnectivityService implements ConnectivityService {
  _FakeConnectivityService(this.isOnline);

  @override
  bool? isOnline;

  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  @override
  Future<void> start() async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

class _FakeAuthService extends AuthService {
  @override
  Future<String?> getCurrentUserId() async => 'user-a';

  @override
  Future<http.Response> authenticatedRequest({
    required String method,
    required String path,
    Map<String, String>? headers,
    Object? body,
  }) async => http.Response('', 204);
}

class _FakeActivityService extends ActivityService {
  List<JoinedActivityRecord> remote = const [];
  Object? joinedActivitiesError;
  final List<String> leaveRequests = [];

  _FakeActivityService({
    required super.authService,
    required super.localRepository,
  });

  @override
  Future<List<JoinedActivityRecord>> getJoinedActivities({
    required String userId,
  }) async {
    final error = joinedActivitiesError;
    if (error != null) throw error;
    return remote;
  }

  @override
  Future<void> leave(String activityId) async {
    leaveRequests.add(activityId);
  }
}

ActivityRecord _activity() {
  return ActivityRecord(
    id: 'activity-1',
    title: 'Taller de arte',
    category: 'CULTURA',
    startTime: '2026-12-01T10:00:00Z',
    endTime: '2026-12-01T12:00:00Z',
    locationName: 'Campus',
    latitude: 4.6,
    longitude: -74,
    participants: 2,
    cachedAt: DateTime.utc(2026, 11, 20),
  );
}

JoinedActivityRecord _remote(ActivityRecord activity) {
  final now = DateTime.utc(2026, 11, 20);
  return JoinedActivityRecord(
    activity: activity,
    userId: 'user-a',
    enrollmentStatus: JoinedEnrollmentStatus.confirmed,
    syncStatus: JoinedSyncStatus.synced,
    enrollmentId: 'enrollment-1',
    joinedAt: now,
    createdAt: now,
    updatedAt: now,
    syncedAt: now,
  );
}

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase appDatabase;
  late ActivityLocalRepository activityRepository;
  late PendingActionsRepository pendingRepository;
  late JoinedActivitiesRepository joinedRepository;
  late _FakeActivityService activityService;
  late _FakeConnectivityService connectivity;
  late PendingActionsSyncService syncService;
  late JoinedActivitiesViewModel viewModel;

  setUp(() async {
    authSession.setAuthenticated();
    appDatabase = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    final database = await appDatabase.database;
    activityRepository = ActivityLocalRepository(
      database,
      capacityService: StorageCapacityService(
        readAvailableBytes: () async => 1 << 40,
        minimumFreeBytes: 0,
        safetyMarginBytes: 0,
      ),
    );
    pendingRepository = PendingActionsRepository(database);
    final authService = _FakeAuthService();
    connectivity = _FakeConnectivityService(true);
    activityService = _FakeActivityService(
      authService: authService,
      localRepository: activityRepository,
    );
    joinedRepository = JoinedActivitiesRepository(
      database,
      activityRepository,
      pendingRepository,
      activityService: activityService,
    );
    syncService = PendingActionsSyncService(
      connectivityService: connectivity,
      repository: pendingRepository,
      authService: authService,
      activityService: activityService,
      joinedActivitiesRepository: joinedRepository,
    );
    viewModel = JoinedActivitiesViewModel(
      joinedRepository,
      activityService: activityService,
      authService: authService,
      connectivityService: connectivity,
      syncService: syncService,
      now: () => DateTime.utc(2026, 11, 26),
    );
  });

  tearDown(() async {
    viewModel.dispose();
    await syncService.stop();
    await connectivity.dispose();
    await activityRepository.dispose();
    await appDatabase.close();
    authSession.setUnauthenticated();
  });

  test(
    'loads local activities while offline without contacting the backend',
    () async {
      final activity = _activity();
      await activityRepository.upsertAll([activity]);
      await joinedRepository.reconcileFromBackend(
        userId: 'user-a',
        remote: [_remote(activity)],
      );
      connectivity.isOnline = false;

      await viewModel.load();

      expect(viewModel.activities, hasLength(1));
      expect(viewModel.isOffline, isTrue);
      expect(activityService.remote, isEmpty);
    },
  );

  test(
    'shows an interrupted processing action as pending while offline',
    () async {
      final activity = _activity();
      await activityRepository.upsertAll([activity]);
      final now = DateTime.utc(2026, 11, 20);
      await joinedRepository.enqueueJoin(
        PendingAction(
          id: 'join-1',
          userId: 'user-a',
          type: PendingActionType.joinActivity,
          activityId: activity.id,
          payload: const {},
          status: PendingActionStatus.processing,
          attempts: 0,
          createdAt: now,
          updatedAt: now,
        ),
      );
      connectivity.isOnline = false;

      await viewModel.load();

      expect(viewModel.activities.single.syncStatus, JoinedSyncStatus.pending);
    },
  );

  test('keeps cached activities when the joined endpoint fails', () async {
    final activity = _activity();
    await activityRepository.upsertAll([activity]);
    await joinedRepository.reconcileFromBackend(
      userId: 'user-a',
      remote: [_remote(activity)],
    );
    activityService.joinedActivitiesError = const ActivityException(
      'Service unavailable',
      statusCode: 503,
    );

    await viewModel.load();

    expect(viewModel.activities, hasLength(1));
    expect(viewModel.refreshError, contains('Service unavailable'));
  });

  test('queues an offline leave and preserves its pending state', () async {
    final activity = _activity();
    await activityRepository.upsertAll([activity]);
    await joinedRepository.reconcileFromBackend(
      userId: 'user-a',
      remote: [_remote(activity)],
    );
    activityService.remote = [_remote(activity)];
    await viewModel.load();
    connectivity.isOnline = false;

    await viewModel.leaveActivity(viewModel.activities.single);

    final current = (await joinedRepository.getForUser('user-a')).single;
    expect(current.enrollmentStatus, JoinedEnrollmentStatus.pendingLeave);
    expect(current.syncStatus, JoinedSyncStatus.pending);
    expect(
      (await pendingRepository.getAllByUser('user-a')).single.type,
      PendingActionType.leaveActivity,
    );
    expect(activityService.leaveRequests, isEmpty);
  });

  test(
    'removes a confirmed enrollment after a successful online leave',
    () async {
      final activity = _activity();
      await activityRepository.upsertAll([activity]);
      activityService.remote = [_remote(activity)];
      await viewModel.load();
      final enrollment = viewModel.activities.single;

      await viewModel.leaveActivity(enrollment);

      expect(activityService.leaveRequests, ['activity-1']);
      expect(await joinedRepository.getForUser('user-a'), isEmpty);
    },
  );
}
