import 'package:sqflite/sqflite.dart';
import '../models/pending_action.dart';

class PendingActionsRepository {
  PendingActionsRepository(this._database);

  final Database _database;

  Future<void> enqueue(PendingAction action) async {
    await _database.insert(
      'pending_actions',
      action.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<PendingAction?> getById(String id) async {
    final result = await _database.query(
      'pending_actions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return PendingAction.fromMap(result.first);
  }

  Future<List<PendingAction>> getPending(String userId,) async {
    final result = await _database.query(
      'pending_actions',
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, 'PENDING'],
      orderBy: 'created_at ASC',
    );

    return result.map(PendingAction.fromMap).toList();
  }

  Future<List<PendingAction>> getAllByUser(String userId,) async {
    final result = await _database.query(
      'pending_actions',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at ASC',
    );

    return result.map(PendingAction.fromMap).toList();
  }

  Future<int> update(PendingAction action) async {
    return _database.update(
      'pending_actions',
      action.toMap(),
      where: 'id = ?',
      whereArgs: [action.id],
    );
  }

  Future<int> updateStatus({required String id, required PendingActionStatus status, String? lastError, int? attempts,}) async {
    return _database.update(
      'pending_actions',
      {
        'status': status.name.toUpperCase(),
        'last_error': lastError,
        'attempts': ?attempts,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> delete(String id) async {
    return _database.delete(
      'pending_actions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCompleted(String userId) async {
    return _database.delete(
      'pending_actions',
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, 'COMPLETED'],
    );
  }
}
