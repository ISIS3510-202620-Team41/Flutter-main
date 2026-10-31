import 'package:sqflite/sqflite.dart';
import '../models/activity_record.dart';
import '../cache/activity_memory_cache.dart';

class ActivityLocalRepository {
  ActivityLocalRepository(this._database, {ActivityMemoryCache? cache})
      : _cache = cache ?? ActivityMemoryCache();

  final Database _database;
  final ActivityMemoryCache _cache;

  Future<void> insert(ActivityRecord activity) async {
    await _database.insert(
      'activities',
      activity.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _cache.put(activity);
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
    _cache.putAll(activities);
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
    final count = await _database.update(
      'activities',
      activity.toMap(),
      where: 'id = ?',
      whereArgs: [activity.id],
    );
    if (count > 0) _cache.put(activity);
    return count;
  }

  Future<int> delete(String id) async {
    final count = await _database.delete(
      'activities',
      where: 'id = ?',
      whereArgs: [id],
    );
    _cache.remove(id);
    return count;
  }
  void clearCache() => _cache.clear();
}
