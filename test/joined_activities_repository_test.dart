import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:llamalla/database/app_database.dart';
import 'package:llamalla/models/activity_record.dart';
import 'package:llamalla/models/joined_activity_record.dart';
import 'package:llamalla/models/pending_action.dart';
import 'package:llamalla/repositories/activity_local_repository.dart';
import 'package:llamalla/repositories/joined_activities_repository.dart';
import 'package:llamalla/repositories/pending_actions_repository.dart';

ActivityRecord _activity(String id) {
  return ActivityRecord(
    id: id,
    title: 'Actividad $id',
    category: 'CULTURA',
    startTime: '2027-01-15T10:00:00Z',
    endTime: '2027-01-15T12:00:00Z',
    locationName: 'Campus',
    latitude: 4.6,
    longitude: -74,
    participants: 2,
    cachedAt: DateTime.utc(2026, 11, 1),
  );
}

JoinedActivityRecord _remote(
  ActivityRecord activity, {
  required String userId,
}) {
  final now = DateTime.utc(2026, 11, 20);
  return JoinedActivityRecord(
    activity: activity,
    userId: userId,
    enrollmentStatus: JoinedEnrollmentStatus.confirmed,
    syncStatus: JoinedSyncStatus.synced,
    enrollmentId: 'enrollment-${activity.id}',
    joinedAt: now,
    createdAt: now,
    updatedAt: now,
    syncedAt: now,
  );
}

PendingAction _action({
  required String id,
  required String userId,
  required String activityId,
  required PendingActionType type,
  PendingActionStatus status = PendingActionStatus.pending,
}) {
  final now = DateTime.utc(2026, 11, 21);
  return PendingAction(
    id: id,
    userId: userId,
    type: type,
    activityId: activityId,
    payload: const {},
    status: status,
    attempts: 0,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase appDatabase;
  late ActivityLocalRepository activityRepository;
  late PendingActionsRepository pendingActionsRepository;
  late JoinedActivitiesRepository joinedRepository;

  setUp(() async {
    appDatabase = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    final database = await appDatabase.database;
    activityRepository = ActivityLocalRepository(database);
    pendingActionsRepository = PendingActionsRepository(database);
    joinedRepository = JoinedActivitiesRepository(
      database,
      activityRepository,
      pendingActionsRepository,
    );
  });

  tearDown(() async {
    await activityRepository.dispose();
    await appDatabase.close();
  });

  test(
    'keeps joined activities isolated by user during reconciliation',
    () async {
      final activity = _activity('activity-1');
      await activityRepository.upsertAll([activity]);
      await joinedRepository.reconcileFromBackend(
        userId: 'user-a',
        remote: [_remote(activity, userId: 'user-a')],
      );
      await joinedRepository.reconcileFromBackend(
        userId: 'user-b',
        remote: [_remote(activity, userId: 'user-b')],
      );

      expect(await joinedRepository.getForUser('user-a'), hasLength(1));
      expect(await joinedRepository.getForUser('user-b'), hasLength(1));

      await joinedRepository.reconcileFromBackend(
        userId: 'user-a',
        remote: const [],
      );

      expect(await joinedRepository.getForUser('user-a'), isEmpty);
      expect(await joinedRepository.getForUser('user-b'), hasLength(1));
    },
  );

  test(
    'cancels a queued join when the user leaves before it is sent',
    () async {
      final activity = _activity('activity-1');
      await activityRepository.upsertAll([activity]);
      await joinedRepository.enqueueJoin(
        _action(
          id: 'join-1',
          userId: 'user-a',
          activityId: activity.id,
          type: PendingActionType.joinActivity,
        ),
      );

      expect(await joinedRepository.getForUser('user-a'), hasLength(1));
      expect(
        (await joinedRepository.getForUser('user-a')).single.enrollmentStatus,
        JoinedEnrollmentStatus.pendingJoin,
      );

      await joinedRepository.enqueueLeave(
        _action(
          id: 'leave-1',
          userId: 'user-a',
          activityId: activity.id,
          type: PendingActionType.leaveActivity,
        ),
      );

      expect(await joinedRepository.getForUser('user-a'), isEmpty);
      expect(await pendingActionsRepository.getAllByUser('user-a'), isEmpty);
    },
  );

  test(
    'retains a pending leave when the backend still reports the join',
    () async {
      final activity = _activity('activity-1');
      await activityRepository.upsertAll([activity]);
      await joinedRepository.reconcileFromBackend(
        userId: 'user-a',
        remote: [_remote(activity, userId: 'user-a')],
      );
      await joinedRepository.enqueueLeave(
        _action(
          id: 'leave-1',
          userId: 'user-a',
          activityId: activity.id,
          type: PendingActionType.leaveActivity,
        ),
      );

      await joinedRepository.reconcileFromBackend(
        userId: 'user-a',
        remote: [_remote(activity, userId: 'user-a')],
      );

      final enrollment = (await joinedRepository.getForUser('user-a')).single;
      expect(enrollment.enrollmentStatus, JoinedEnrollmentStatus.pendingLeave);
      expect(enrollment.syncStatus, JoinedSyncStatus.pending);
    },
  );

  test(
    'confirms a queued join already present in the backend response',
    () async {
      final activity = _activity('activity-1');
      await activityRepository.upsertAll([activity]);
      await joinedRepository.enqueueJoin(
        _action(
          id: 'join-1',
          userId: 'user-a',
          activityId: activity.id,
          type: PendingActionType.joinActivity,
        ),
      );

      await joinedRepository.reconcileFromBackend(
        userId: 'user-a',
        remote: [_remote(activity, userId: 'user-a')],
      );

      final enrollment = (await joinedRepository.getForUser('user-a')).single;
      expect(enrollment.enrollmentStatus, JoinedEnrollmentStatus.confirmed);
      expect(enrollment.syncStatus, JoinedSyncStatus.synced);
      expect(await pendingActionsRepository.getAllByUser('user-a'), isEmpty);
    },
  );

  test(
    'clears a queued leave when the backend already reports no enrollment',
    () async {
      final activity = _activity('activity-1');
      await activityRepository.upsertAll([activity]);
      await joinedRepository.reconcileFromBackend(
        userId: 'user-a',
        remote: [_remote(activity, userId: 'user-a')],
      );
      await joinedRepository.enqueueLeave(
        _action(
          id: 'leave-1',
          userId: 'user-a',
          activityId: activity.id,
          type: PendingActionType.leaveActivity,
        ),
      );

      await joinedRepository.reconcileFromBackend(
        userId: 'user-a',
        remote: const [],
      );

      expect(await joinedRepository.getForUser('user-a'), isEmpty);
      expect(await pendingActionsRepository.getAllByUser('user-a'), isEmpty);
    },
  );

  test(
    'deletes the local enrollment after a leave action is confirmed',
    () async {
      final activity = _activity('activity-1');
      await activityRepository.upsertAll([activity]);
      await joinedRepository.reconcileFromBackend(
        userId: 'user-a',
        remote: [_remote(activity, userId: 'user-a')],
      );
      final leave = _action(
        id: 'leave-1',
        userId: 'user-a',
        activityId: activity.id,
        type: PendingActionType.leaveActivity,
      );
      await joinedRepository.enqueueLeave(leave);
      await joinedRepository.updateActionStatus(
        action: leave,
        status: PendingActionStatus.processing,
      );

      await joinedRepository.completeAction(leave);

      expect(await joinedRepository.getForUser('user-a'), isEmpty);
      expect(await pendingActionsRepository.getAllByUser('user-a'), isEmpty);
    },
  );

  test(
    'retries failed queue actions without creating another queue item',
    () async {
      final activity = _activity('activity-1');
      await activityRepository.upsertAll([activity]);
      final join = _action(
        id: 'join-1',
        userId: 'user-a',
        activityId: activity.id,
        type: PendingActionType.joinActivity,
      );
      await joinedRepository.enqueueJoin(join);
      await joinedRepository.updateActionStatus(
        action: join,
        status: PendingActionStatus.failed,
        lastError: 'Rejected',
        attempts: 1,
      );

      final enrollment = (await joinedRepository.getForUser('user-a')).single;
      expect(enrollment.syncStatus, JoinedSyncStatus.failed);

      expect(
        await joinedRepository.retryFailedAction(
          userId: 'user-a',
          activityId: activity.id,
        ),
        isTrue,
      );
      expect(
        (await joinedRepository.getForUser('user-a')).single.syncStatus,
        JoinedSyncStatus.pending,
      );
      expect(
        await pendingActionsRepository.getAllByUser('user-a'),
        hasLength(1),
      );
    },
  );
}
