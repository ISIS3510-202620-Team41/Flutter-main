import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:llamalla/database/app_database.dart';
import 'package:llamalla/models/activity.dart';
import 'package:llamalla/models/activity_record.dart';
import 'package:llamalla/models/storage_capacity.dart';
import 'package:llamalla/repositories/activity_local_repository.dart';
import 'package:llamalla/services/storage_capacity_service.dart';
import 'package:llamalla/services/storage_write_error.dart';

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
    repository = ActivityLocalRepository(
      db,
      capacityService: StorageCapacityService(
        readAvailableBytes: () async => 1 << 40,
        minimumFreeBytes: 0,
        safetyMarginBytes: 0,
      ),
    );
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

  test(
    'rejects optional activity writes when capacity is insufficient',
    () async {
      final reportedErrors = <FlutterErrorDetails>[];
      final previousErrorHandler = FlutterError.onError;
      FlutterError.onError = reportedErrors.add;
      final db = await appDatabase.database;
      final guardedRepository = ActivityLocalRepository(
        db,
        capacityService: StorageCapacityService(
          readAvailableBytes: () async => 10,
          minimumFreeBytes: 100,
          safetyMarginBytes: 0,
        ),
      );

      try {
        await expectLater(
          guardedRepository.insert(
            activity,
            policy: ActivityWritePolicy.optionalCache,
          ),
          throwsA(isA<StorageWriteException>()),
        );
        await expectLater(
          guardedRepository.upsertAll([activity]),
          throwsA(
            isA<StorageWriteException>().having(
              (error) => error.kind,
              'kind',
              StorageFailureKind.capacity,
            ),
          ),
        );
        await expectLater(
          guardedRepository.update(
            activity,
            policy: ActivityWritePolicy.optionalCache,
          ),
          throwsA(isA<StorageWriteException>()),
        );
        expect(await guardedRepository.getAll(), isEmpty);
        expect(reportedErrors, hasLength(3));
      } finally {
        FlutterError.onError = previousErrorHandler;
        await guardedRepository.dispose();
      }
    },
  );

  test(
    'cleans cached activities but preserves essential activity records',
    () async {
      final db = await appDatabase.database;
      final reportedErrors = <FlutterErrorDetails>[];
      final previousErrorHandler = FlutterError.onError;
      FlutterError.onError = reportedErrors.add;
      final guardedRepository = ActivityLocalRepository(
        db,
        capacityService: StorageCapacityService(
          readAvailableBytes: () async => 10,
          minimumFreeBytes: 100,
          safetyMarginBytes: 0,
        ),
      );
      final offlineActivity = ActivityRecord(
        id: '${localActivityIdPrefix}draft',
        title: 'Offline activity',
        category: 'DEPORTES',
        startTime: activity.startTime,
        endTime: activity.endTime,
        locationName: activity.locationName,
        latitude: activity.latitude,
        longitude: activity.longitude,
        participants: 0,
        cachedAt: activity.cachedAt,
      );
      final cachedActivity = ActivityRecord(
        id: 'activity-cache',
        title: 'Cached activity',
        category: 'DEPORTES',
        startTime: activity.startTime,
        endTime: activity.endTime,
        locationName: activity.locationName,
        latitude: activity.latitude,
        longitude: activity.longitude,
        participants: 0,
        cachedAt: activity.cachedAt,
      );

      try {
        await guardedRepository.upsertAll([
          activity,
          offlineActivity,
          cachedActivity,
        ], policy: ActivityWritePolicy.essential);
        await db.insert('joined_activities', {
          'user_id': 'user-1',
          'activity_id': activity.id,
          'enrollment_status': 'CONFIRMED',
          'sync_status': 'SYNCED',
          'created_at': activity.cachedAt.toIso8601String(),
          'updated_at': activity.cachedAt.toIso8601String(),
        });

        await expectLater(
          guardedRepository.upsertAll([activity]),
          throwsA(isA<StorageWriteException>()),
        );

        expect(
          (await guardedRepository.getAll()).map((item) => item.id).toSet(),
          {activity.id, offlineActivity.id},
        );
        expect(await db.query('joined_activities'), hasLength(1));
        expect(reportedErrors, hasLength(1));
      } finally {
        FlutterError.onError = previousErrorHandler;
        await guardedRepository.dispose();
      }
    },
  );

  test('essential offline inserts do not depend on capacity checks', () async {
    final guardedRepository = ActivityLocalRepository(
      await appDatabase.database,
      capacityService: StorageCapacityService(
        readAvailableBytes: () async =>
            throw StateError('provider unavailable'),
      ),
    );

    try {
      await guardedRepository.insert(activity);
      expect(await guardedRepository.getById(activity.id), isNotNull);
    } finally {
      await guardedRepository.dispose();
    }
  });

  test('watchAll emits initial data and updates after insert', () async {
    final firstEmission = Completer<List<ActivityRecord>>();

    final secondEmission = Completer<List<ActivityRecord>>();

    var emissions = 0;

    final subscription = repository.watchAll().listen((records) {
      if (emissions == 0 && !firstEmission.isCompleted) {
        firstEmission.complete(records);
      } else if (emissions == 1 && !secondEmission.isCompleted) {
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
