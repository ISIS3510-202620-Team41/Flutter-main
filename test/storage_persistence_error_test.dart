import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llamalla/database/app_database.dart';
import 'package:llamalla/models/activity_record.dart';
import 'package:llamalla/models/pending_action.dart';
import 'package:llamalla/models/storage_capacity.dart';
import 'package:llamalla/repositories/activity_local_repository.dart';
import 'package:llamalla/repositories/pending_actions_repository.dart';
import 'package:llamalla/services/storage_capacity_service.dart';
import 'package:llamalla/services/storage_write_error.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> _limitDatabaseToOneMorePage(Database database) async {
  final pageCount =
      (await database.rawQuery('PRAGMA page_count')).single.values.single
          as int;
  await database.execute('PRAGMA max_page_count = ${pageCount + 1}');
}

void main() {
  setUpAll(sqfliteFfiInit);

  test('classifies a full SQLite activity write and reports it', () async {
    final appDatabase = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    final database = await appDatabase.database;
    await _limitDatabaseToOneMorePage(database);
    final repository = ActivityLocalRepository(
      database,
      capacityService: StorageCapacityService(
        readAvailableBytes: () async => 0,
        minimumFreeBytes: 1,
        safetyMarginBytes: 0,
      ),
    );
    final reportedErrors = <FlutterErrorDetails>[];
    final previousErrorHandler = FlutterError.onError;
    FlutterError.onError = reportedErrors.add;

    try {
      await expectLater(
        repository.insert(
          ActivityRecord(
            id: 'large-activity',
            title: 'Large activity',
            description: 'x' * 65536,
            category: 'CULTURE',
            startTime: '2026-11-27T10:00:00Z',
            endTime: '2026-11-27T11:00:00Z',
            locationName: 'Campus',
            latitude: 4.6,
            longitude: -74,
            participants: 0,
            cachedAt: DateTime.utc(2026, 11, 27),
          ),
        ),
        throwsA(
          isA<StorageWriteException>().having(
            (error) => error.kind,
            'kind',
            StorageFailureKind.capacity,
          ),
        ),
      );
      expect(reportedErrors, hasLength(1));
    } finally {
      FlutterError.onError = previousErrorHandler;
      await repository.dispose();
      await appDatabase.close();
    }
  });

  test(
    'classifies a full SQLite pending-action write without eviction',
    () async {
      final appDatabase = AppDatabase(
        databaseFactory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      final database = await appDatabase.database;
      await _limitDatabaseToOneMorePage(database);
      final repository = PendingActionsRepository(database);
      final now = DateTime.utc(2026, 11, 27);
      final reportedErrors = <FlutterErrorDetails>[];
      final previousErrorHandler = FlutterError.onError;
      FlutterError.onError = reportedErrors.add;

      try {
        await expectLater(
          repository.enqueue(
            PendingAction(
              id: 'action-1',
              userId: 'user-1',
              type: PendingActionType.joinActivity,
              activityId: 'activity-1',
              payload: {'data': 'x' * 65536},
              status: PendingActionStatus.pending,
              attempts: 0,
              createdAt: now,
              updatedAt: now,
            ),
          ),
          throwsA(
            isA<StorageWriteException>().having(
              (error) => error.kind,
              'kind',
              StorageFailureKind.capacity,
            ),
          ),
        );
        expect(reportedErrors, hasLength(1));
        expect(await repository.getPending('user-1'), isEmpty);
      } finally {
        FlutterError.onError = previousErrorHandler;
        await appDatabase.close();
      }
    },
  );
}
