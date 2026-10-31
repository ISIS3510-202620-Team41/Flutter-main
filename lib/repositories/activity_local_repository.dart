import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../models/activity_record.dart';

class ActivityLocalRepository {
  ActivityLocalRepository(this._database);

  final Database _database;

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

    _notifyActivitiesChanged();
  }

  Future<ActivityRecord?> getById(String id) async {
    final result = await _database.query(
      'activities',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return ActivityRecord.fromMap(result.first);
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

    if (rows > 0) {
      _notifyActivitiesChanged();
    }

    return rows;
  }

  Future<void> dispose() async {
    await _changesController.close();
  }
}
