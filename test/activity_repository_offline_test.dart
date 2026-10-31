import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:llamalla/database/app_database.dart';
import 'package:llamalla/models/activity.dart';
import 'package:llamalla/models/activity_draft.dart';
import 'package:llamalla/models/pending_action.dart';
import 'package:llamalla/repositories/activity_local_repository.dart';
import 'package:llamalla/repositories/activity_repository.dart';
import 'package:llamalla/repositories/pending_actions_repository.dart';
import 'package:llamalla/services/activity_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeService extends ActivityService {
  final created = <Map<String, dynamic>>[];
  Object? error;

  @override
  Future<Activity> createActivity(
      Map<String, dynamic> body, {
        String? source,
      }) async {
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

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase appDatabase;
  late ActivityLocalRepository activities;
  late PendingActionsRepository pending;
  late _FakeService service;
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
    repository = ActivityRepository(
      service: service,
      localRepository: activities,
      pendingActions: pending,
      isOnline: () async => online,
      userId: () async => 'user-1',
    );
  });

  tearDown(() => appDatabase.close());

  test('offline creation saves the activity and queues CREATE_ACTIVITY', () async {
    final result = await repository.create(draft);

    expect(result.savedOffline, isTrue);
    expect(result.activity.isPendingSync, isTrue);
    expect(service.created, isEmpty);
    expect(await activities.getById('local-client-1'), isNotNull);

    final queue = await pending.getPending('user-1');
    expect(queue, hasLength(1));
    expect(queue.first.type, PendingActionType.createActivity);
    expect(queue.first.payload['title'], 'Deportes en Bistro');
  });

  test('syncPending sends the activity and clears the queue', () async {
    await repository.create(draft);
    online = true;

    final synced = await repository.syncPending();

    expect(synced, 1);
    expect(service.created, hasLength(1));
    expect(await activities.getById('local-client-1'), isNull);
    expect(await pending.getPending('user-1'), isEmpty);
  });

  test('a network failure keeps the task pending', () async {
    await repository.create(draft);
    service.error = const SocketException('offline');

    final synced = await repository.syncPending();

    expect(synced, 0);
    expect(await activities.getById('local-client-1'), isNotNull);
    expect(await pending.getPending('user-1'), hasLength(1));
  });
}