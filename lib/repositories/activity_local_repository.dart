import 'package:sqflite/sqflite.dart';
import '../models/activity_record.dart';

class ActivityLocalRepository {
  ActivityLocalRepository(this._database);

  final Database _database;

  Future<void> insert(ActivityRecord activity) async {
    await _database.insert(
      'activities',
      activity.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertAll(List<ActivityRecord> activities) async {
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
    return _database.update(
      'activities',
      activity.toMap(),
      where: 'id = ?',
      whereArgs: [activity.id],
    );
  }

  Future<int> delete(String id) async {
    return _database.delete(
      'activities',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
