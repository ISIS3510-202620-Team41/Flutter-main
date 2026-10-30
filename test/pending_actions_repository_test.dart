import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:llamalla/database/app_database.dart';
import 'package:llamalla/models/pending_action.dart';
import 'package:llamalla/repositories/pending_actions_repository.dart';

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

    final db = await appDatabase.database;
    repository = PendingActionsRepository(db);
  });

  tearDown(() async {
    await appDatabase.close();
  });

  final action = PendingAction(
    id: 'action-1',
    userId: 'user-1',
    type: PendingActionType.joinActivity,
    activityId: 'activity-1',
    payload: {
      'recommendationId': 'recommendation-1',
      'freeTimeMinutes': 90,
    },
    status: PendingActionStatus.pending,
    attempts: 0,
    createdAt: DateTime.utc(2026, 10, 29),
    updatedAt: DateTime.utc(2026, 10, 29),
  );

  test('enqueues and retrieves an action', () async {
    await repository.enqueue(action);

    final result = await repository.getById('action-1');

    expect(result, isNotNull);
    expect(result!.type, PendingActionType.joinActivity);
    expect(result.payload['freeTimeMinutes'], 90);
  });

  test('retrieves only pending actions for a user', () async {
    await repository.enqueue(action);

    final result = await repository.getPending('user-1');
    final otherUser = await repository.getPending('user-2');

    expect(result.length, 1);
    expect(otherUser, isEmpty);
  });

  test('updates action status', () async {
    await repository.enqueue(action);

    final rows = await repository.updateStatus(
      id: action.id,
      status: PendingActionStatus.failed,
      lastError: 'Network unavailable',
      attempts: 1,
    );

    final result = await repository.getById(action.id);

    expect(rows, 1);
    expect(result!.status, PendingActionStatus.failed);
    expect(result.attempts, 1);
    expect(result.lastError, 'Network unavailable');
  });

  test('updates an action using its model', () async {
    await repository.enqueue(action);

    final updated = action.copyWith(
      status: PendingActionStatus.completed,
    );

    final rows = await repository.update(updated);
    final result = await repository.getById(action.id);

    expect(rows, 1);
    expect(result!.status, PendingActionStatus.completed);
  });

  test('deletes an action', () async {
    await repository.enqueue(action);

    final rows = await repository.delete(action.id);
    final result = await repository.getById(action.id);

    expect(rows, 1);
    expect(result, isNull);
  });
}
