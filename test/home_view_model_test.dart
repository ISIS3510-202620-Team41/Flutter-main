import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:llamalla/analytics/analytics_facade.dart';
import 'package:llamalla/database/app_database.dart';
import 'package:llamalla/models/activity.dart';
import 'package:llamalla/models/pending_action.dart';
import 'package:llamalla/models/profile_models.dart';
import 'package:llamalla/repositories/pending_actions_repository.dart';
import 'package:llamalla/services/activity_service.dart';
import 'package:llamalla/services/auth_service.dart';
import 'package:llamalla/services/connectivity_service.dart';
import 'package:llamalla/services/location_service.dart';
import 'package:llamalla/services/pending_actions_sync_service.dart';
import 'package:llamalla/services/profile_service.dart';
import 'package:llamalla/services/schedule_service.dart';
import 'package:llamalla/viewmodels/home_view_model.dart';

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

class _TestAuthService extends AuthService {
  @override
  Future<String?> getCurrentUserId() async => 'user-1';
}

class _FakeConnectivityService implements ConnectivityService {
  _FakeConnectivityService(this.isOnline);

  @override
  bool? isOnline;

  final StreamController<bool> _controller =
      StreamController<bool>.broadcast();

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

class _ProfileService extends ProfileService {
  @override
  Future<UserProfile> getCurrentUser() async => const UserProfile(
        id: 'user-1',
        email: 'juan@test.com',
        name: 'Juan Pérez',
        bio: '',
      );
}

class _ScheduleService extends ScheduleService {
  @override
  Future<DayGaps> getGaps({
    required DateTime date,
    String timezone = 'America/Bogota',
  }) async {
    return DayGaps(
      date: date,
      timezone: timezone,
      free: [
        FreeInterval(
          start: DateTime(2026, 10, 3, 11, 30),
          end: DateTime(2026, 10, 3, 13),
        ),
      ],
    );
  }
}

class _FailingScheduleService extends ScheduleService {
  @override
  Future<DayGaps> getGaps({
    required DateTime date,
    String timezone = 'America/Bogota',
  }) async {
    throw const ScheduleException('Schedule unavailable');
  }
}

class _ActivityService extends ActivityService {
  String? joinedId;
  String? joinedRecommendationId;
  int? joinedFreeMinutes;

  int joinCalls = 0;

  Object? joinError;

  @override
  Future<RecommendationBatch> getRecommendations({
    required double lat,
    required double lon,
    double radiusKm = 5,
    String timezone = 'America/Bogota',
    bool calculateDistanceLocally = true,
  }) async {
    return const RecommendationBatch(
      activities: [
        Activity(
          id: 'activity-1',
          category: 'Sports',
          name: 'Run',
          distance: '500 m',
          duration: '30 min',
          price: '',
          people: '0 registered',
          imageUrl: '',
        ),
      ],
      recommendationId: 'recommendation-1',
      freeMinutes: 45,
    );
  }

  @override
  Future<void> join(
    String activityId, {
    String? recommendationId,
    int? freeTimeMinutes,
  }) async {
    joinCalls++;

    if (joinError != null) {
      throw joinError!;
    }

    joinedId = activityId;
    joinedRecommendationId = recommendationId;
    joinedFreeMinutes = freeTimeMinutes;
  }
}

class _LocationService extends LocationService {
  @override
  Future<LocationResult> current() async {
    return LocationResult(
      location: const UserLocation(4.6, -74.08),
    );
  }
}

PendingAction _pendingAction({
  String id = 'action-1',
  String activityId = 'activity-1',
}) {
  return PendingAction(
    id: id,
    userId: 'user-1',
    type: PendingActionType.joinActivity,
    activityId: activityId,
    payload: const {
      'recommendationId': 'recommendation-1',
      'freeTimeMinutes': 45,
    },
    status: PendingActionStatus.pending,
    attempts: 0,
    createdAt: DateTime.utc(2026, 10, 3),
    updatedAt: DateTime.utc(2026, 10, 3),
  );
}

HomeViewModel _createViewModel({
  required PendingActionsRepository repository,
  required _FakeConnectivityService connectivity,
  _ActivityService? activityService,
  ScheduleService? scheduleService,
  _RecordingAnalyticsFacade? analytics,
  _TestAuthService? authService,
}) {
  final auth = authService ?? _TestAuthService();

  final syncService = PendingActionsSyncService(
    connectivityService: connectivity,
    repository: repository,
    authService: auth,
  );

  return HomeViewModel(
    profileService: _ProfileService(),
    scheduleService: scheduleService ?? _ScheduleService(),
    activityService: activityService ?? _ActivityService(),
    locationService: _LocationService(),
    now: () => DateTime(2026, 10, 3, 9),
    analyticsFacade: analytics ?? _RecordingAnalyticsFacade(),
    pendingActionsRepository: repository,
    connectivityService: connectivity,
    authService: auth,
    syncService: syncService,
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  late AppDatabase appDatabase;
  late PendingActionsRepository repository;

  setUp(() async {
    appDatabase = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );

    final database = await appDatabase.database;
    repository = PendingActionsRepository(database);
  });

  tearDown(() async {
    await appDatabase.close();
  });

  test('loads profile name and derives the next free interval', () async {
    final connectivity = _FakeConnectivityService(true);

    final viewModel = _createViewModel(
      repository: repository,
      connectivity: connectivity,
    );

    await viewModel.load();

    expect(viewModel.greetingName, 'Juan');
    expect(viewModel.freeMinutes, 90);
    expect(
      formatClockTime(viewModel.nextFreeInterval!.start),
      '11:30 AM',
    );
    expect(viewModel.errorMessage, isNull);

    viewModel.dispose();
    await connectivity.dispose();
  });

  test('loads recommendations and preserves join analytics context', () async {
    final activityService = _ActivityService();
    final analytics = _RecordingAnalyticsFacade();
    final connectivity = _FakeConnectivityService(true);

    final viewModel = _createViewModel(
      repository: repository,
      connectivity: connectivity,
      activityService: activityService,
      analytics: analytics,
    );

    await viewModel.load();

    expect(analytics.featureEvents, isEmpty);
    expect(viewModel.recommendations, hasLength(1));

    expect(
      await viewModel.choose(viewModel.recommendations.single),
      isTrue,
    );

    expect(activityService.joinedId, 'activity-1');
    expect(
      activityService.joinedRecommendationId,
      'recommendation-1',
    );
    expect(activityService.joinedFreeMinutes, 45);

    expect(analytics.featureEvents, [
      {
        'feature': 'activity_recommendations',
        'action': 'select_recommendation',
        'screen': 'Home',
      },
      {
        'feature': 'activity_joining',
        'action': 'join_recommended_activity',
        'screen': 'Home',
      },
    ]);

    viewModel.dispose();
    await connectivity.dispose();
  });

  test('loads recommendations even when the schedule request fails', () async {
    final connectivity = _FakeConnectivityService(true);

    final viewModel = _createViewModel(
      repository: repository,
      connectivity: connectivity,
      scheduleService: _FailingScheduleService(),
    );

    await viewModel.load();

    expect(viewModel.errorMessage, 'Schedule unavailable');
    expect(viewModel.recommendations, hasLength(1));

    viewModel.dispose();
    await connectivity.dispose();
  });

  test('does not track activity joining when join fails', () async {
    final activityService = _ActivityService()
      ..joinError = Exception('Join failed');

    final analytics = _RecordingAnalyticsFacade();
    final connectivity = _FakeConnectivityService(true);

    final viewModel = _createViewModel(
      repository: repository,
      connectivity: connectivity,
      activityService: activityService,
      analytics: analytics,
    );

    await viewModel.load();

    final result = await viewModel.choose(
      viewModel.recommendations.single,
    );

    expect(result, isFalse);

    expect(
      analytics.featureEvents.map((event) => event['feature']),
      ['activity_recommendations'],
    );

    expect(await repository.getPending('user-1'), isEmpty);

    viewModel.dispose();
    await connectivity.dispose();
  });

  test('does not track an activity without an ID', () async {
    final activityService = _ActivityService();
    final analytics = _RecordingAnalyticsFacade();
    final connectivity = _FakeConnectivityService(true);

    final viewModel = _createViewModel(
      repository: repository,
      connectivity: connectivity,
      activityService: activityService,
      analytics: analytics,
    );

    await viewModel.load();

    const activityWithoutId = Activity(
      id: null,
      category: 'Sports',
      name: 'Run',
      distance: '500 m',
      duration: '30 min',
      price: '',
      people: '0 registered',
      imageUrl: '',
    );

    expect(
      await viewModel.choose(activityWithoutId),
      isFalse,
    );

    expect(analytics.featureEvents, isEmpty);
    expect(activityService.joinedId, isNull);
    expect(await repository.getPending('user-1'), isEmpty);

    viewModel.dispose();
    await connectivity.dispose();
  });

  test('queues a join locally when there is no connectivity', () async {
    final activityService = _ActivityService();
    final connectivity = _FakeConnectivityService(false);

    final viewModel = _createViewModel(
      repository: repository,
      connectivity: connectivity,
      activityService: activityService,
    );

    await viewModel.load();

    final result = await viewModel.choose(
      viewModel.recommendations.single,
    );

    final pending = await repository.getPending('user-1');

    expect(result, isTrue);
    expect(viewModel.wasLastJoinQueued, isTrue);
    expect(viewModel.isActivityPending('activity-1'), isTrue);

    expect(pending, hasLength(1));
    expect(pending.single.activityId, 'activity-1');
    expect(pending.single.type, PendingActionType.joinActivity);
    expect(pending.single.status, PendingActionStatus.pending);

    expect(
      pending.single.payload,
      {
        'recommendationId': 'recommendation-1',
        'freeTimeMinutes': 45,
      },
    );

    expect(activityService.joinCalls, 0);

    viewModel.dispose();
    await connectivity.dispose();
  });

  test('queues a join when the backend returns a retryable 503 error', () async {
    final activityService = _ActivityService()
      ..joinError = const ActivityException(
        'Service unavailable',
        statusCode: 503,
      );

    final connectivity = _FakeConnectivityService(true);

    final viewModel = _createViewModel(
      repository: repository,
      connectivity: connectivity,
      activityService: activityService,
    );

    await viewModel.load();

    final result = await viewModel.choose(
      viewModel.recommendations.single,
    );

    final pending = await repository.getPending('user-1');

    expect(result, isTrue);
    expect(viewModel.wasLastJoinQueued, isTrue);
    expect(viewModel.isActivityPending('activity-1'), isTrue);

    expect(pending, hasLength(1));
    expect(pending.single.status, PendingActionStatus.pending);
    expect(
      pending.single.payload['recommendationId'],
      'recommendation-1',
    );
    expect(pending.single.payload['freeTimeMinutes'], 45);
    expect(activityService.joinCalls, 1);

    viewModel.dispose();
    await connectivity.dispose();
  });

  test('queues a join when the request fails due to a network exception',
      () async {
    final activityService = _ActivityService()
      ..joinError = http.ClientException('Connection refused');

    final connectivity = _FakeConnectivityService(true);

    final viewModel = _createViewModel(
      repository: repository,
      connectivity: connectivity,
      activityService: activityService,
    );

    await viewModel.load();

    final result = await viewModel.choose(
      viewModel.recommendations.single,
    );

    final pending = await repository.getPending('user-1');

    expect(result, isTrue);
    expect(viewModel.wasLastJoinQueued, isTrue);
    expect(pending, hasLength(1));
    expect(pending.single.status, PendingActionStatus.pending);

    viewModel.dispose();
    await connectivity.dispose();
  });

  test('does not queue a join when the backend returns a 404 error', () async {
    final activityService = _ActivityService()
      ..joinError = const ActivityException(
        'Activity not found',
        statusCode: 404,
      );

    final connectivity = _FakeConnectivityService(true);

    final viewModel = _createViewModel(
      repository: repository,
      connectivity: connectivity,
      activityService: activityService,
    );

    await viewModel.load();

    final result = await viewModel.choose(
      viewModel.recommendations.single,
    );

    expect(result, isFalse);
    expect(viewModel.wasLastJoinQueued, isFalse);
    expect(viewModel.isActivityPending('activity-1'), isFalse);
    expect(viewModel.actionMessage, 'Activity not found');
    expect(await repository.getPending('user-1'), isEmpty);

    viewModel.dispose();
    await connectivity.dispose();
  });

  test('does not enqueue duplicate joins for an already pending activity',
      () async {
    final activityService = _ActivityService();
    final connectivity = _FakeConnectivityService(false);

    final viewModel = _createViewModel(
      repository: repository,
      connectivity: connectivity,
      activityService: activityService,
    );

    await viewModel.load();

    final firstResult = await viewModel.choose(
      viewModel.recommendations.single,
    );

    final secondResult = await viewModel.choose(
      viewModel.recommendations.single,
    );

    final pending = await repository.getPending('user-1');

    expect(firstResult, isTrue);
    expect(secondResult, isTrue);
    expect(viewModel.wasLastJoinQueued, isTrue);
    expect(viewModel.isActivityPending('activity-1'), isTrue);

    expect(pending, hasLength(1));
    expect(activityService.joinCalls, 0);
    expect(
      viewModel.actionMessage,
      'Esta inscripción ya está pendiente.',
    );

    viewModel.dispose();
    await connectivity.dispose();
  });

  test('restores pending activity IDs from the local repository on load',
      () async {
    await repository.enqueue(_pendingAction());

    final connectivity = _FakeConnectivityService(true);

    final viewModel = _createViewModel(
      repository: repository,
      connectivity: connectivity,
    );

    await viewModel.load();

    expect(viewModel.isActivityPending('activity-1'), isTrue);
    expect(viewModel.isActivityPending('activity-2'), isFalse);

    viewModel.dispose();
    await connectivity.dispose();
  });
}
