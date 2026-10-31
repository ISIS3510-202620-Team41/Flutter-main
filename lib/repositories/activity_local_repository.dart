import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../models/activity_record.dart';
import '../cache/activity_memory_cache.dart';

class ActivityLocalRepository {
  ActivityLocalRepository(this._database, {ActivityMemoryCache? cache})
      : _cache = cache ?? ActivityMemoryCache();

  final Database _database;
  final ActivityMemoryCache _cache;

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
  
  Future<void> insert(ActivityRecord activity) async {
    await _database.insert(
      'activities',
      activity.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _cache.put(activity);

    _notifyActivitiesChanged();
  }

  Future<void> upsertAll(List<ActivityRecord> activities) async {
    if (activities.isEmpty) return;

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

  Future<List<ActivityRecord>> getByCategory(
    String category,
  ) async {
    final result = await _database.query(
      'activities',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'start_time ASC',
    );

    return result.map(ActivityRecord.fromMap).toList();
  }

  Future<int> update(ActivityRecord activity) async {
    final rows = await _database.update(
      'activities',
      activity.toMap(),
      where: 'id = ?',
      whereArgs: [activity.id],
    );

    if (rows > 0) {
      _cache.put(activity);
      _notifyActivitiesChanged();
    }

    return rows;
  }

  Future<int> delete(String id) async {
    final rows = await _database.delete(
      'activities',
      where: 'id = ?',
      whereArgs: [id],
    );
    _cache.remove(id);
    if (rows > 0) {
      _notifyActivitiesChanged();
    }

    return rows;
  }
  
   void clearCache() => _cache.clear();

  Future<void> dispose() async {
    await _changesController.close();
  }
}
