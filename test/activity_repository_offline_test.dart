import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:llamalla/analytics/analytics_facade.dart';
import 'package:llamalla/database/app_database.dart';
import 'package:llamalla/models/activity.dart';
import 'package:llamalla/models/activity_draft.dart';
import 'package:llamalla/models/pending_action.dart';
import 'package:llamalla/models/plan_creation_context.dart';
import 'package:llamalla/repositories/activity_local_repository.dart';
import 'package:llamalla/repositories/activity_repository.dart';
import 'package:llamalla/repositories/pending_actions_repository.dart';
import 'package:llamalla/services/activity_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeService extends ActivityService {
  final created = <Map<String, dynamic>>[];
  final requests = <Map<String, dynamic>>[];
  final sources = <String?>[];
  Object? error;

  @override
  Future<Activity> createActivity(
    Map<String, dynamic> body, {
    String? source,
  }) async {
    sources.add(source);
    requests.add(Map<String, dynamic>.from(body));
    if (error != null) throw error!;
    created.add(body);
    return const Activity(
      id: 'server-1',
      category: 'Deportes',
      name: 'Server',
      distance: '',
      duration: '',
      price: '',
      people: '',
      imageUrl: '',
    );
  }
}

class _RecordingAnalyticsFacade extends AnalyticsFacade {
  final attempts = <({String attemptId, PlanCreationContext context})>[];

  @override
  Future<void> trackPlanCreationAttempted({
    required String attemptId,
    required PlanCreationContext context,
  }) async {
    attempts.add((attemptId: attemptId, context: context));
  }
}

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase appDatabase;
  late ActivityLocalRepository activities;
  late PendingActionsRepository pending;
  late _FakeService service;
  late _RecordingAnalyticsFacade analytics;
  late ActivityRepository repository;
  var online = false;

  final draft = ActivityDraft(
    clientId: 'client-1',
    title: 'Deportes en Bistro',
    category: 'DEPORTES',
    startTime: DateTime.utc(2026, 10, 30, 17),
    endTime: DateTime.utc(2026, 10, 30, 19),
    locationName: 'Bistro',
    latitude: 4.6,
    longitude: -74.0,
    friends: const ['Alex'],
    price: '\$30K',
    capacity: 10,
    aboutLocation: 'Restaurante',
    attemptId: '4a3cb35e-b63b-4e16-9f98-885d20a7a4fd',
    planCreationContext: const PlanCreationContext(
      preferences: ['DEPORTES'],
      freeTimeMinutes: 120,
      locationName: 'Bistro',
      latitude: 4.6,
      longitude: -74,
      availableFriendsCount: 3,
      selectedAvailableFriendsCount: 1,
    ),
  );

  setUp(() async {
    online = false;
    appDatabase = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    final db = await appDatabase.database;
    activities = ActivityLocalRepository(db);
    pending = PendingActionsRepository(db);
    service = _FakeService();
    analytics = _RecordingAnalyticsFacade();
    repository = ActivityRepository(
      service: service,
      localRepository: activities,
      pendingActions: pending,
      analyticsFacade: analytics,
      isOnline: () async => online,
      userId: () async => 'user-1',
    );
  });

  tearDown(() => appDatabase.close());

  test(
    'offline creation saves the activity and queues CREATE_ACTIVITY',
    () async {
      final result = await repository.create(
        draft,
        source: 'friend_availability',
      );

      expect(result.savedOffline, isTrue);
      expect(result.activity.isPendingSync, isTrue);
      expect(service.created, isEmpty);
      expect(await activities.getById('local-client-1'), isNotNull);

      final queue = await pending.getPending('user-1');
      expect(queue, hasLength(1));
      expect(queue.first.type, PendingActionType.createActivity);
      expect(queue.first.payload['title'], 'Deportes en Bistro');
      expect(
        queue.first.payload['attemptId'],
        '4a3cb35e-b63b-4e16-9f98-885d20a7a4fd',
      );
      expect(
        queue.first.payload['_planCreationContext'],
        draft.planCreationContext!.toMap(),
      );
      expect(queue.first.payload['_creationSource'], 'friend_availability');
      expect(analytics.attempts, hasLength(1));
      expect(
        analytics.attempts.single.attemptId,
        queue.first.payload['attemptId'],
      );
      expect(
        analytics.attempts.single.context.selectedAvailableFriendsCount,
        1,
      );
    },
  );

  test(
    'syncPending reuses attemptId and does not republish the attempt',
    () async {
      await repository.create(draft, source: 'friend_availability');
      online = true;

      final synced = await repository.syncPending();

      expect(synced, 1);
      expect(service.created, hasLength(1));
      expect(
        service.created.single['attemptId'],
        '4a3cb35e-b63b-4e16-9f98-885d20a7a4fd',
      );
      expect(
        service.created.single.containsKey('_planCreationContext'),
        isFalse,
      );
      expect(service.created.single.containsKey('_creationSource'), isFalse);
      expect(service.sources, ['friend_availability']);
      expect(analytics.attempts, hasLength(1));
      expect(await activities.getById('local-client-1'), isNull);
      expect(await pending.getPending('user-1'), isEmpty);
    },
  );

  test('a network failure retries with the same attemptId', () async {
    await repository.create(draft);
    service.error = const SocketException('offline');

    final synced = await repository.syncPending();

    expect(synced, 0);
    expect(await activities.getById('local-client-1'), isNotNull);
    expect(await pending.getPending('user-1'), hasLength(1));
    final firstAttemptId = service.requests.single['attemptId'];

    service.error = null;
    expect(await repository.syncPending(), 1);

    expect(service.requests, hasLength(2));
    expect(service.requests[1]['attemptId'], firstAttemptId);
    expect(analytics.attempts, hasLength(1));
  });
}
