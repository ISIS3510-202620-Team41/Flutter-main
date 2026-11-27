import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../models/activity_record.dart';
import '../cache/activity_memory_cache.dart';
import '../models/activity.dart';
import '../models/storage_capacity.dart';
import '../services/storage_capacity_service.dart';
import '../services/storage_cleanup_service.dart';
import '../services/storage_write_error.dart';

enum ActivityWritePolicy { essential, optionalCache }

class ActivityLocalRepository {
  ActivityLocalRepository(
    this._database, {
    ActivityMemoryCache? cache,
    StorageCapacityService? capacityService,
    StorageCleanupService? cleanupService,
  }) : _cache = cache ?? ActivityMemoryCache(),
       _capacityService = capacityService ?? StorageCapacityService.shared {
    _cleanupService =
        cleanupService ??
        StorageCleanupService(
          capacityService: _capacityService,
          steps: [
            StorageCleanupStep(
              name: 'cached activities',
              cleanup: clearOptionalCache,
            ),
          ],
        );
  }

  final Database _database;
  final ActivityMemoryCache _cache;
  final StorageCapacityService _capacityService;
  late final StorageCleanupService _cleanupService;

  // Notifica cuando cambia la tabla de actividades de la db.
  final StreamController<void> _changesController =
      StreamController<void>.broadcast();

  Stream<List<ActivityRecord>> watchAll() {
    return Stream<List<ActivityRecord>>.multi((controller) {
      var cancelled = false;

      // Cola para evitar consultas y emisiones desordenadas.
      Future<void> emissionQueue = Future.value();

      void scheduleSnapshot() {
        emissionQueue = emissionQueue.then((_) async {
          if (cancelled) return;

          try {
            // Obtenemos nuevamente los registros de SQLite.
            final records = await getAll();

            if (!cancelled) {
              controller.add(records);
            }
          } catch (error, stackTrace) {
            if (!cancelled) {
              controller.addError(error, stackTrace);
            }
          }
        });
      }

      // Escuchamos cambios en la db
      final subscription = _changesController.stream.listen(
        (_) => scheduleSnapshot(),
        onDone: () {
          emissionQueue = emissionQueue.then((_) async {
            if (!cancelled) {
              await controller.close();
            }
          });
        },
      );

      // Emitimos inicialmente los registros almacenados.
      scheduleSnapshot();

      controller.onCancel = () async {
        cancelled = true;

        await subscription.cancel();
        await emissionQueue;
      };
    });
  }

  // Notifica a todos los suscriptores que hubo un cambio.
  void _notifyActivitiesChanged() {
    if (!_changesController.isClosed) {
      _changesController.add(null);
    }
  }

  Future<void> insert(
    ActivityRecord activity, {
    ActivityWritePolicy policy = ActivityWritePolicy.essential,
  }) async {
    if (policy == ActivityWritePolicy.optionalCache) {
      await _ensureCapacity([activity]);
    }
    await runStorageWrite('activity insert', () async {
      await _database.insert(
        'activities',
        activity.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    _cache.put(activity);

    _notifyActivitiesChanged();
  }

  Future<void> upsertAll(
    List<ActivityRecord> activities, {
    ActivityWritePolicy policy = ActivityWritePolicy.optionalCache,
  }) async {
    if (activities.isEmpty) return;

    if (policy == ActivityWritePolicy.optionalCache) {
      await _ensureCapacity(activities);
    }

    await runStorageWrite('activity batch upsert', () async {
      await _database.transaction((txn) async {
        final batch = txn.batch();

        for (final activity in activities) {
          batch.insert(
            'activities',
            activity.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        await batch.commit(noResult: true);
      });
    });
    _cache.putAll(activities);

    _notifyActivitiesChanged();
  }

  Future<ActivityRecord?> getById(String id) async {
    final cached = _cache.get(id);
    if (cached != null) return cached;

    final result = await _database.query(
      'activities',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;

    final record = ActivityRecord.fromMap(result.first);
    _cache.put(record);
    return record;
  }

  Future<List<ActivityRecord>> getAll() async {
    final result = await _database.query(
      'activities',
      orderBy: 'start_time ASC',
    );

    return result.map(ActivityRecord.fromMap).toList();
  }

  Future<List<ActivityRecord>> getByCategory(String category) async {
    final result = await _database.query(
      'activities',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'start_time ASC',
    );

    return result.map(ActivityRecord.fromMap).toList();
  }

  /// Activities created offline that were not sent to the backend yet.
  Future<List<ActivityRecord>> getPendingSync() async {
    final result = await _database.query(
      'activities',
      where: 'id LIKE ?',
      whereArgs: ['$localActivityIdPrefix%'],
      orderBy: 'start_time ASC',
    );

    return result.map(ActivityRecord.fromMap).toList();
  }

  Future<int> update(
    ActivityRecord activity, {
    ActivityWritePolicy policy = ActivityWritePolicy.essential,
  }) async {
    if (policy == ActivityWritePolicy.optionalCache) {
      await _ensureCapacity([activity]);
    }
    final rows = await runStorageWrite('activity update', () {
      return _database.update(
        'activities',
        activity.toMap(),
        where: 'id = ?',
        whereArgs: [activity.id],
      );
    });

    if (rows > 0) {
      _cache.put(activity);
      _notifyActivitiesChanged();
    }

    return rows;
  }

  Future<void> _ensureCapacity(List<ActivityRecord> activities) async {
    final estimatedBytes = activities.fold<int>(
      0,
      (total, activity) =>
          total + utf8.encode(jsonEncode(activity.toMap())).length + 128,
    );
    final capacity = await _cleanupService.makeRoomForOptionalWrite(
      estimatedWriteBytes: estimatedBytes,
    );
    if (capacity.status == StorageCapacityStatus.sufficient) return;

    final failure = StorageWriteException(
      kind: capacity.status == StorageCapacityStatus.insufficient
          ? StorageFailureKind.capacity
          : capacity.failureKind ?? StorageFailureKind.provider,
      operation: 'optional activity cache write',
      cause: StateError(
        capacity.errorMessage ??
            'Insufficient storage for optional activity data.',
      ),
    );
    reportStorageFailure(failure, StackTrace.current);
    throw failure;
  }

  Future<int> delete(String id) async {
    final rows = await runStorageWrite('activity delete', () {
      return _database.delete('activities', where: 'id = ?', whereArgs: [id]);
    });
    _cache.remove(id);
    if (rows > 0) {
      _notifyActivitiesChanged();
    }

    return rows;
  }

  Future<void> clearOptionalCache() async {
    final rows = await runStorageWrite('activity cache cleanup', () {
      return _database.delete(
        'activities',
        where: '''
          id NOT LIKE ?
          AND id NOT IN (SELECT activity_id FROM joined_activities)
          AND id NOT IN (
            SELECT activity_id
            FROM pending_actions
            WHERE action_type = 'CREATE_ACTIVITY'
          )
        ''',
        whereArgs: ['$localActivityIdPrefix%'],
      );
    });

    if (rows > 0) {
      _cache.clear();
      _notifyActivitiesChanged();
    }
  }

  void clearCache() => _cache.clear();

  Future<void> dispose() async {
    await _changesController.close();
  }
}
