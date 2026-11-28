import 'package:sqflite/sqflite.dart';

import '../cache/joined_activity_lru_cache.dart';
import '../models/activity_record.dart';
import '../models/joined_activity_record.dart';
import '../models/pending_action.dart';
import '../services/activity_service.dart';
import '../services/storage_write_error.dart';
import 'activity_local_repository.dart';
import 'pending_actions_repository.dart';

class JoinedActivitiesRepository {
  JoinedActivitiesRepository(
    this._database,
    this._activityRepository,
    this._pendingActionsRepository, {
    ActivityService? activityService,
    JoinedActivityLruCache? activityCache,
    DateTime Function()? now,
  }) : _activityService =
           activityService ??
           ActivityService(localRepository: _activityRepository),
       _activityCache = activityCache ?? JoinedActivityLruCache(),
       _now = now ?? DateTime.now;

  static const _joinType = 'JOIN_ACTIVITY';
  static const _leaveType = 'LEAVE_ACTIVITY';

  final Database _database;
  final ActivityLocalRepository _activityRepository;
  final PendingActionsRepository _pendingActionsRepository;
  final ActivityService _activityService;
  final JoinedActivityLruCache _activityCache;
  final DateTime Function() _now;
  String? _activeUserId;

  static const _joinedSelect = '''
    SELECT
      activities.*,
      joined_activities.user_id AS joined_user_id,
      joined_activities.enrollment_status AS joined_enrollment_status,
      joined_activities.sync_status AS joined_sync_status,
      joined_activities.enrollment_id AS joined_enrollment_id,
      joined_activities.joined_at AS joined_at,
      joined_activities.created_at AS joined_created_at,
      joined_activities.updated_at AS joined_updated_at,
      joined_activities.synced_at AS joined_synced_at,
      joined_activities.last_error AS joined_last_error
    FROM joined_activities
    INNER JOIN activities
      ON activities.id = joined_activities.activity_id
    WHERE joined_activities.user_id = ?
  ''';

  Future<List<JoinedActivityRecord>> getForUser(String userId) async {
    _activateUser(userId);
    final rows = await _database.rawQuery(
      '$_joinedSelect ORDER BY activities.start_time ASC',
      [userId],
    );
    final records = rows
        .map(JoinedActivityRecord.fromDatabaseMap)
        .toList(growable: false);
    _activityCache.replaceForUser(userId, records);
    return records;
  }

  List<JoinedActivityRecord>? getCachedForUser(String userId) {
    _activateUser(userId);
    return _activityCache.getForUser(userId);
  }

  void clearMemoryCache() {
    _activityCache.clear();
    _activeUserId = null;
  }

  Future<void> refreshFromBackend(String userId) async {
    _activateUser(userId);
    final remote = await _activityService.getJoinedActivities(userId: userId);

    final records = <ActivityRecord>[];
    for (final enrollment in remote) {
      final previous = await _activityRepository.getById(
        enrollment.activity.id,
      );
      records.add(
        enrollment.activity.copyWith(localImagePath: previous?.localImagePath),
      );
    }
    await _activityRepository.upsertAll(
      records,
      policy: ActivityWritePolicy.essential,
    );
    _activityCache.clearUser(userId);
    await reconcileFromBackend(userId: userId, remote: remote);
  }

  Future<void> reconcileFromBackend({
    required String userId,
    required List<JoinedActivityRecord> remote,
  }) async {
    if (remote.any((item) => item.userId != userId)) {
      throw ArgumentError(
        'Joined activities can only be reconciled for their owner.',
      );
    }
    _activateUser(userId);

    final now = _now().toUtc();
    final remoteById = {for (final item in remote) item.activity.id: item};

    await _writeTransaction('joined activity reconciliation', (
      transaction,
    ) async {
      final existingRows = await transaction.query(
        'joined_activities',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      final existingById = {
        for (final row in existingRows) row['activity_id'] as String: row,
      };
      final actionRows = await transaction.query(
        'pending_actions',
        where: 'user_id = ? AND action_type IN (?, ?) AND status != ?',
        whereArgs: [userId, _joinType, _leaveType, 'COMPLETED'],
        orderBy: 'created_at ASC',
      );
      final actionsById = _groupActions(actionRows);
      final activityIds = <String>{
        ...existingById.keys,
        ...remoteById.keys,
        ...actionsById.keys,
      };

      for (final activityId in activityIds) {
        final actions = actionsById[activityId] ?? const <PendingAction>[];
        final latestAction = _latestAction(actions);
        final remoteRecord = remoteById[activityId];
        final current = existingById[activityId];

        final hasProcessingAction = actions.any(
          (action) => action.status == PendingActionStatus.processing,
        );
        if (!hasProcessingAction &&
            latestAction?.type == PendingActionType.joinActivity &&
            remoteRecord != null) {
          for (final action in actions) {
            await _pendingActionsRepository.deleteInTransaction(
              transaction,
              action.id,
            );
          }
          await transaction.insert(
            'joined_activities',
            remoteRecord.copyWith(updatedAt: now).toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          continue;
        }
        if (!hasProcessingAction &&
            latestAction?.type == PendingActionType.leaveActivity &&
            remoteRecord == null) {
          for (final action in actions) {
            await _pendingActionsRepository.deleteInTransaction(
              transaction,
              action.id,
            );
          }
          await transaction.delete(
            'joined_activities',
            where: 'user_id = ? AND activity_id = ?',
            whereArgs: [userId, activityId],
          );
          continue;
        }

        if (latestAction != null) {
          await _writeActionState(
            transaction,
            userId: userId,
            activityId: activityId,
            action: latestAction,
            current: current,
            remote: remoteRecord,
            now: now,
          );
        } else if (remoteRecord != null) {
          await transaction.insert(
            'joined_activities',
            remoteRecord.copyWith(updatedAt: now).toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } else if (current != null) {
          await transaction.delete(
            'joined_activities',
            where: 'user_id = ? AND activity_id = ?',
            whereArgs: [userId, activityId],
          );
        }
      }
    }, userId: userId);
  }

  Future<void> recordConfirmedJoin({
    required String userId,
    required String activityId,
  }) async {
    final now = _now().toUtc();
    await _writeTransaction('confirmed activity join persistence', (
      transaction,
    ) async {
      final actions = await _readActions(
        transaction,
        userId: userId,
        activityId: activityId,
      );
      for (final action in actions.where(
        (action) =>
            action.type == PendingActionType.leaveActivity &&
            action.status != PendingActionStatus.processing,
      )) {
        await _pendingActionsRepository.deleteInTransaction(
          transaction,
          action.id,
        );
      }

      final remaining = await _readActions(
        transaction,
        userId: userId,
        activityId: activityId,
      );
      final latest = _latestAction(remaining);
      if (latest != null) {
        final current = await _readRelation(
          transaction,
          userId: userId,
          activityId: activityId,
        );
        await _writeActionState(
          transaction,
          userId: userId,
          activityId: activityId,
          action: latest,
          current: current,
          now: now,
        );
        return;
      }

      final current = await _readRelation(
        transaction,
        userId: userId,
        activityId: activityId,
      );
      await _writeRelation(
        transaction,
        userId: userId,
        activityId: activityId,
        enrollmentStatus: JoinedEnrollmentStatus.confirmed,
        syncStatus: JoinedSyncStatus.synced,
        enrollmentId: current?['enrollment_id'] as String?,
        joinedAt: current?['joined_at'] as String? ?? now.toIso8601String(),
        createdAt: current?['created_at'] as String? ?? now.toIso8601String(),
        updatedAt: now.toIso8601String(),
        syncedAt: now.toIso8601String(),
      );
    }, userId: userId, activityId: activityId);
  }

  Future<void> enqueueJoin(PendingAction action) async {
    _requireType(action, PendingActionType.joinActivity);
    final now = _now().toUtc();
    await _writeTransaction('pending activity join persistence', (
      transaction,
    ) async {
      final actions = await _readActions(
        transaction,
        userId: action.userId,
        activityId: action.activityId,
      );
      for (final opposite in actions.where(
        (item) =>
            item.type == PendingActionType.leaveActivity &&
            item.status != PendingActionStatus.processing,
      )) {
        await _pendingActionsRepository.deleteInTransaction(
          transaction,
          opposite.id,
        );
      }

      final existingJoin = actions.where(
        (item) =>
            item.type == PendingActionType.joinActivity &&
            item.status != PendingActionStatus.completed,
      );
      if (existingJoin.isEmpty) {
        await _pendingActionsRepository.enqueueInTransaction(
          transaction,
          action,
        );
      } else {
        final failed = existingJoin.where(
          (item) => item.status == PendingActionStatus.failed,
        );
        for (final item in failed) {
          await _pendingActionsRepository.updateStatusInTransaction(
            transaction,
            id: item.id,
            status: PendingActionStatus.pending,
            lastError: null,
          );
        }
      }

      final remaining = await _readActions(
        transaction,
        userId: action.userId,
        activityId: action.activityId,
      );
      final latest = _latestAction(remaining);
      if (latest != null) {
        await _writeActionState(
          transaction,
          userId: action.userId,
          activityId: action.activityId,
          action: latest,
          now: now,
        );
      }
    }, userId: action.userId, activityId: action.activityId);
  }

  Future<void> enqueueLeave(PendingAction action) async {
    _requireType(action, PendingActionType.leaveActivity);
    final now = _now().toUtc();
    await _writeTransaction('pending activity leave persistence', (
      transaction,
    ) async {
      final actions = await _readActions(
        transaction,
        userId: action.userId,
        activityId: action.activityId,
      );
      final processingJoin = actions.any(
        (item) =>
            item.type == PendingActionType.joinActivity &&
            item.status == PendingActionStatus.processing,
      );

      if (!processingJoin) {
        final unsentJoins = actions.where(
          (item) =>
              item.type == PendingActionType.joinActivity &&
              item.status != PendingActionStatus.completed,
        );
        if (unsentJoins.isNotEmpty) {
          for (final item in actions.where(
            (item) => item.status != PendingActionStatus.processing,
          )) {
            await _pendingActionsRepository.deleteInTransaction(
              transaction,
              item.id,
            );
          }
          final remaining = await _readActions(
            transaction,
            userId: action.userId,
            activityId: action.activityId,
          );
          final latest = _latestAction(remaining);
          if (latest == null) {
            await transaction.delete(
              'joined_activities',
              where: 'user_id = ? AND activity_id = ?',
              whereArgs: [action.userId, action.activityId],
            );
          } else {
            await _writeActionState(
              transaction,
              userId: action.userId,
              activityId: action.activityId,
              action: latest,
              now: now,
            );
          }
          return;
        }
      }

      final existingLeave = actions.where(
        (item) =>
            item.type == PendingActionType.leaveActivity &&
            item.status != PendingActionStatus.completed,
      );
      if (existingLeave.isEmpty) {
        await _pendingActionsRepository.enqueueInTransaction(
          transaction,
          action,
        );
      } else {
        for (final item in existingLeave.where(
          (item) => item.status == PendingActionStatus.failed,
        )) {
          await _pendingActionsRepository.updateStatusInTransaction(
            transaction,
            id: item.id,
            status: PendingActionStatus.pending,
            lastError: null,
          );
        }
      }

      final remaining = await _readActions(
        transaction,
        userId: action.userId,
        activityId: action.activityId,
      );
      final latest = _latestAction(remaining);
      if (latest != null) {
        await _writeActionState(
          transaction,
          userId: action.userId,
          activityId: action.activityId,
          action: latest,
          now: now,
        );
      }
    }, userId: action.userId, activityId: action.activityId);
  }

  Future<void> updateActionStatus({
    required PendingAction action,
    required PendingActionStatus status,
    String? lastError,
    int? attempts,
  }) async {
    final now = _now().toUtc();
    await _writeTransaction('pending activity status persistence', (
      transaction,
    ) async {
      await _pendingActionsRepository.updateStatusInTransaction(
        transaction,
        id: action.id,
        status: status,
        lastError: lastError,
        attempts: attempts,
      );
      final actions = await _readActions(
        transaction,
        userId: action.userId,
        activityId: action.activityId,
      );
      final latest = _latestAction(actions);
      if (latest != null) {
        await _writeActionState(
          transaction,
          userId: action.userId,
          activityId: action.activityId,
          action: latest,
          now: now,
        );
      }
    }, userId: action.userId, activityId: action.activityId);
  }

  Future<void> completeAction(PendingAction action) async {
    final now = _now().toUtc();
    await _writeTransaction('activity action completion persistence', (
      transaction,
    ) async {
      await _pendingActionsRepository.deleteInTransaction(
        transaction,
        action.id,
      );
      final actions = await _readActions(
        transaction,
        userId: action.userId,
        activityId: action.activityId,
      );
      final latest = _latestAction(actions);
      if (latest != null) {
        final current = await _readRelation(
          transaction,
          userId: action.userId,
          activityId: action.activityId,
        );
        await _writeActionState(
          transaction,
          userId: action.userId,
          activityId: action.activityId,
          action: latest,
          current: current,
          now: now,
        );
      } else if (action.type == PendingActionType.joinActivity) {
        final current = await _readRelation(
          transaction,
          userId: action.userId,
          activityId: action.activityId,
        );
        await _writeRelation(
          transaction,
          userId: action.userId,
          activityId: action.activityId,
          enrollmentStatus: JoinedEnrollmentStatus.confirmed,
          syncStatus: JoinedSyncStatus.synced,
          enrollmentId: current?['enrollment_id'] as String?,
          joinedAt: current?['joined_at'] as String? ?? now.toIso8601String(),
          createdAt: current?['created_at'] as String? ?? now.toIso8601String(),
          updatedAt: now.toIso8601String(),
          syncedAt: now.toIso8601String(),
        );
      } else if (action.type == PendingActionType.leaveActivity) {
        await transaction.delete(
          'joined_activities',
          where: 'user_id = ? AND activity_id = ?',
          whereArgs: [action.userId, action.activityId],
        );
      }
    }, userId: action.userId, activityId: action.activityId);
  }

  Future<bool> retryFailedAction({
    required String userId,
    required String activityId,
  }) async {
    final now = _now().toUtc();
    return _writeTransaction('failed activity action retry', (
      transaction,
    ) async {
      final actions = await _readActions(
        transaction,
        userId: userId,
        activityId: activityId,
      );
      final failed = actions.where(
        (action) => action.status == PendingActionStatus.failed,
      );
      if (failed.isEmpty) return false;

      for (final action in failed) {
        await _pendingActionsRepository.updateStatusInTransaction(
          transaction,
          id: action.id,
          status: PendingActionStatus.pending,
          lastError: null,
        );
      }
      final remaining = await _readActions(
        transaction,
        userId: userId,
        activityId: activityId,
      );
      final latest = _latestAction(remaining);
      if (latest != null) {
        await _writeActionState(
          transaction,
          userId: userId,
          activityId: activityId,
          action: latest,
          now: now,
        );
      }
      return true;
    }, userId: userId, activityId: activityId);
  }

  Future<void> recordConfirmedLeave({
    required String userId,
    required String activityId,
  }) async {
    await _writeTransaction('confirmed activity leave persistence', (
      transaction,
    ) async {
      final actions = await _readActions(
        transaction,
        userId: userId,
        activityId: activityId,
      );
      for (final action in actions.where(
        (item) => item.status != PendingActionStatus.processing,
      )) {
        await _pendingActionsRepository.deleteInTransaction(
          transaction,
          action.id,
        );
      }
      final remaining = await _readActions(
        transaction,
        userId: userId,
        activityId: activityId,
      );
      final latest = _latestAction(remaining);
      if (latest == null) {
        await transaction.delete(
          'joined_activities',
          where: 'user_id = ? AND activity_id = ?',
          whereArgs: [userId, activityId],
        );
      } else {
        final current = await _readRelation(
          transaction,
          userId: userId,
          activityId: activityId,
        );
        await _writeActionState(
          transaction,
          userId: userId,
          activityId: activityId,
          action: latest,
          current: current,
          now: _now().toUtc(),
        );
      }
    }, userId: userId, activityId: activityId);
  }

  Future<List<PendingAction>> _readActions(
    DatabaseExecutor executor, {
    required String userId,
    required String activityId,
  }) async {
    final rows = await executor.query(
      'pending_actions',
      where:
          'user_id = ? AND activity_id = ? AND action_type IN (?, ?) AND status != ?',
      whereArgs: [userId, activityId, _joinType, _leaveType, 'COMPLETED'],
      orderBy: 'created_at ASC',
    );
    return rows.map(PendingAction.fromMap).toList(growable: false);
  }

  Map<String, List<PendingAction>> _groupActions(
    List<Map<String, Object?>> rows,
  ) {
    final grouped = <String, List<PendingAction>>{};
    for (final row in rows) {
      final action = PendingAction.fromMap(row);
      (grouped[action.activityId] ??= <PendingAction>[]).add(action);
    }
    return grouped;
  }

  PendingAction? _latestAction(List<PendingAction> actions) {
    if (actions.isEmpty) return null;
    final ordered = List<PendingAction>.of(actions)
      ..sort((left, right) {
        final createdOrder = left.createdAt.compareTo(right.createdAt);
        return createdOrder != 0
            ? createdOrder
            : left.updatedAt.compareTo(right.updatedAt);
      });
    return ordered.last;
  }

  Future<Map<String, Object?>?> _readRelation(
    DatabaseExecutor executor, {
    required String userId,
    required String activityId,
  }) async {
    final rows = await executor.query(
      'joined_activities',
      where: 'user_id = ? AND activity_id = ?',
      whereArgs: [userId, activityId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> _writeActionState(
    DatabaseExecutor executor, {
    required String userId,
    required String activityId,
    required PendingAction action,
    Map<String, Object?>? current,
    JoinedActivityRecord? remote,
    required DateTime now,
  }) async {
    await _writeRelation(
      executor,
      userId: userId,
      activityId: activityId,
      enrollmentStatus: action.type == PendingActionType.joinActivity
          ? JoinedEnrollmentStatus.pendingJoin
          : JoinedEnrollmentStatus.pendingLeave,
      syncStatus: _syncStatusFor(action.status),
      enrollmentId:
          remote?.enrollmentId ?? current?['enrollment_id'] as String?,
      joinedAt:
          remote?.joinedAt?.toIso8601String() ??
          current?['joined_at'] as String?,
      createdAt:
          current?['created_at'] as String? ??
          remote?.createdAt.toIso8601String() ??
          now.toIso8601String(),
      updatedAt: now.toIso8601String(),
      syncedAt:
          remote?.syncedAt?.toIso8601String() ??
          current?['synced_at'] as String?,
      lastError: action.lastError,
    );
  }

  Future<void> _writeRelation(
    DatabaseExecutor executor, {
    required String userId,
    required String activityId,
    required JoinedEnrollmentStatus enrollmentStatus,
    required JoinedSyncStatus syncStatus,
    String? enrollmentId,
    String? joinedAt,
    required String createdAt,
    required String updatedAt,
    String? syncedAt,
    String? lastError,
  }) async {
    await executor.insert('joined_activities', {
      'user_id': userId,
      'activity_id': activityId,
      'enrollment_status': enrollmentStatus.databaseValue,
      'sync_status': syncStatus.databaseValue,
      'enrollment_id': enrollmentId,
      'joined_at': joinedAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'synced_at': syncedAt,
      'last_error': lastError,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<T> _writeTransaction<T>(
    String operation,
    Future<T> Function(Transaction transaction) action, {
    required String userId,
    String? activityId,
  }) async {
    _activateUser(userId);
    final result = await runStorageWrite(
      operation,
      () => _database.transaction(action),
    );
    if (activityId == null) {
      _activityCache.clearUser(userId);
    } else {
      _activityCache.invalidate(userId: userId, activityId: activityId);
    }
    return result;
  }

  void _activateUser(String userId) {
    if (_activeUserId != null && _activeUserId != userId) {
      _activityCache.clear();
    }
    _activeUserId = userId;
  }

  JoinedSyncStatus _syncStatusFor(PendingActionStatus status) {
    switch (status) {
      case PendingActionStatus.pending:
        return JoinedSyncStatus.pending;
      case PendingActionStatus.processing:
        return JoinedSyncStatus.processing;
      case PendingActionStatus.failed:
        return JoinedSyncStatus.failed;
      case PendingActionStatus.completed:
        return JoinedSyncStatus.synced;
    }
  }

  void _requireType(PendingAction action, PendingActionType expected) {
    if (action.type != expected) {
      throw ArgumentError.value(action.type, 'action.type');
    }
  }
}
