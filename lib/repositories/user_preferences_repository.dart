import 'package:sqflite/sqflite.dart';
import '../models/user_preference.dart';

class UserPreferencesRepository {
  UserPreferencesRepository(this._database);

  final Database _database;

  Future<void> insert(UserPreference preference) async {
    await _database.insert(
      'user_preferences',
      preference.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<UserPreference?> getById(String id) async {
    final result = await _database.query(
      'user_preferences',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return UserPreference.fromMap(result.first);
  }

  Future<List<UserPreference>> getByUserId(
    String userId,
  ) async {
    final result = await _database.query(
      'user_preferences',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'category ASC',
    );

    return result.map(UserPreference.fromMap).toList();
  }

  Future<UserPreference?> getByCategory({
    required String userId,
    required String category,
  }) async {
    final result = await _database.query(
      'user_preferences',
      where: 'user_id = ? AND category = ?',
      whereArgs: [userId, category],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return UserPreference.fromMap(result.first);
  }

  Future<int> update(UserPreference preference) async {
    return _database.update(
      'user_preferences',
      preference.toMap(),
      where: 'id = ?',
      whereArgs: [preference.id],
    );
  }

  Future<void> upsert(UserPreference preference) async {
    await _database.insert(
      'user_preferences',
      preference.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> delete(String id) async {
    return _database.delete(
      'user_preferences',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteByUserId(String userId) async {
    return _database.delete(
      'user_preferences',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }
}
