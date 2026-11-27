import 'package:sqflite/sqflite.dart';
import '../models/pending_action.dart';
import '../services/storage_write_error.dart';

class PendingActionsRepository {
  PendingActionsRepository(this._database);

  final Database _database;

  Future<void> enqueue(PendingAction action) async {
    await runStorageWrite('pending action enqueue', () async {
      await _database.insert(
        'pending_actions',
        action.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    });
  }

  Future<void> enqueueInTransaction(
    Transaction transaction,
    PendingAction action,
  ) async {
    await runStorageWrite('pending action enqueue', () async {
      await transaction.insert(
        'pending_actions',
        action.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    });
  }

  Future<void> deleteInTransaction(Transaction transaction, String id) async {
    await runStorageWrite('pending action removal', () async {
      await transaction.delete(
        'pending_actions',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> updateStatusInTransaction(
    Transaction transaction, {
    required String id,
    required PendingActionStatus status,
    String? lastError,
    int? attempts,
  }) async {
    final values = <String, Object?>{
      'status': status.name.toUpperCase(),
      'last_error': lastError,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (attempts != null) values['attempts'] = attempts;

    await runStorageWrite('pending action status update', () async {
      await transaction.update(
        'pending_actions',
        values,
        where: 'id = ?',
        whereArgs: [id],
      );
    });
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

  Future<List<PendingAction>> getPending(String userId) async {
    final result = await _database.query(
      'pending_actions',
      where: 'user_id = ? AND status IN (?, ?)',
      whereArgs: [
        userId,
        PendingActionStatus.pending.name.toUpperCase(),
        PendingActionStatus.processing.name.toUpperCase(),
      ],
      orderBy: 'created_at ASC',
    );

    return result.map(PendingAction.fromMap).toList();
  }

  Future<List<PendingAction>> getAllByUser(String userId) async {
    final result = await _database.query(
      'pending_actions',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at ASC',
    );

    return result.map(PendingAction.fromMap).toList();
  }

  Future<int> recoverProcessing(String userId) async {
    return runStorageWrite('pending action recovery', () {
      return _database.update(
        'pending_actions',
        {
          'status': 'PENDING',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'user_id = ? AND status = ?',
        whereArgs: [userId, 'PROCESSING'],
      );
    });
  }

  Future<int> update(PendingAction action) async {
    return runStorageWrite('pending action update', () {
      return _database.update(
        'pending_actions',
        action.toMap(),
        where: 'id = ?',
        whereArgs: [action.id],
      );
    });
  }

  Future<int> updateStatus({
    required String id,
    required PendingActionStatus status,
    String? lastError,
    int? attempts,
  }) async {
    final values = <String, Object?>{
      'status': status.name.toUpperCase(),
      'last_error': lastError,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (attempts != null) {
      values['attempts'] = attempts;
    }

    return runStorageWrite('pending action status update', () {
      return _database.update(
        'pending_actions',
        values,
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<int> delete(String id) async {
    return runStorageWrite('pending action removal', () {
      return _database.delete(
        'pending_actions',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<int> deleteCompleted(String userId) async {
    return runStorageWrite('completed pending action cleanup', () {
      return _database.delete(
        'pending_actions',
        where: 'user_id = ? AND status = ?',
        whereArgs: [userId, 'COMPLETED'],
      );
    });
  }
}
