import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:llamalla/database/app_database.dart';
import 'package:llamalla/models/activity_record.dart';
import 'package:llamalla/repositories/activity_local_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  late AppDatabase appDatabase;
  late ActivityLocalRepository repository;

  setUp(() async {
    appDatabase = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );

    final db = await appDatabase.database;
    repository = ActivityLocalRepository(db);
  });

  tearDown(() async {
    await repository.dispose();
    await appDatabase.close();
  });

  final activity = ActivityRecord(
    id: 'activity-1',
    title: 'Football',
    category: 'DEPORTES',
    startTime: '2026-10-30T17:00:00-05:00',
    endTime: '2026-10-30T19:00:00-05:00',
    locationName: 'University courts',
    latitude: 4.6382,
    longitude: -74.0840,
    participants: 3,
    cachedAt: DateTime.utc(2026, 10, 29),
  );

  test('creates and retrieves an activity', () async {
    await repository.insert(activity);

    final result = await repository.getById('activity-1');

    expect(result, isNotNull);
    expect(result!.title, 'Football');
    expect(result.category, 'DEPORTES');
    expect(result.participants, 3);
  });

  test('updates an existing activity', () async {
    await repository.insert(activity);

    final updated = ActivityRecord(
      id: activity.id,
      title: 'Updated football',
      category: activity.category,
      startTime: activity.startTime,
      endTime: activity.endTime,
      locationName: activity.locationName,
      latitude: activity.latitude,
      longitude: activity.longitude,
      participants: 5,
      cachedAt: DateTime.utc(2026, 10, 29),
    );

    final rows = await repository.update(updated);
    final result = await repository.getById(activity.id);

    expect(rows, 1);
    expect(result!.title, 'Updated football');
    expect(result.participants, 5);
  });

  test('deletes an activity', () async {
    await repository.insert(activity);

    final rows = await repository.delete(activity.id);
    final result = await repository.getById(activity.id);

    expect(rows, 1);
    expect(result, isNull);
  });

  test('upserts multiple activities', () async {
    final second = ActivityRecord(
      id: 'activity-2',
      title: 'Basketball',
      category: 'DEPORTES',
      startTime: '2026-10-31T17:00:00-05:00',
      endTime: '2026-10-31T19:00:00-05:00',
      locationName: 'University courts',
      latitude: 4.6382,
      longitude: -74.0840,
      participants: 2,
      cachedAt: DateTime.utc(2026, 10, 29),
    );

    await repository.upsertAll([activity, second]);

    final result = await repository.getAll();

    expect(result.length, 2);
  });
  test('watchAll emits initial data and updates after insert', () async {
    final firstEmission =
        Completer<List<ActivityRecord>>();

    final secondEmission =
        Completer<List<ActivityRecord>>();

    var emissions = 0;

    final subscription = repository.watchAll().listen((records) {
      if (emissions == 0 && !firstEmission.isCompleted) {
        firstEmission.complete(records);
      } else if (emissions == 1 &&
          !secondEmission.isCompleted) {
        secondEmission.complete(records);
      }

      emissions++;
    });

    // 1. El stream debe emitir inicialmente una lista vacía.
    final initialRecords = await firstEmission.future;

    expect(initialRecords, isEmpty);

    // 2. Insertamos una actividad.
    await repository.insert(activity);

    // 3. El stream debe emitir la nueva lista.
    final updatedRecords = await secondEmission.future;

    expect(updatedRecords, hasLength(1));
    expect(updatedRecords.first.id, activity.id);

    await subscription.cancel();
  });
}
