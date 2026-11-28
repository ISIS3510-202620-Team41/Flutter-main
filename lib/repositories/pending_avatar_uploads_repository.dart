import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/pending_avatar_upload.dart';
import '../services/storage_write_error.dart';

class PendingAvatarUploadsRepository {
  PendingAvatarUploadsRepository(
    this._database, {
    Uuid? uuid,
    DateTime Function()? now,
  }) : _uuid = uuid ?? const Uuid(),
       _now = now ?? DateTime.now;

  final Database _database;
  final Uuid _uuid;
  final DateTime Function() _now;

  Future<PendingAvatarUpload> enqueueLatest({
    required String userId,
    required String localPath,
  }) async {
    final now = _now().toUtc();
    final upload = PendingAvatarUpload(
      id: _uuid.v4(),
      userId: userId,
      localPath: localPath,
      status: AvatarUploadStatus.pending,
      attemptCount: 0,
      createdAt: now,
      updatedAt: now,
    );

    await runStorageWrite('pending avatar upload enqueue', () async {
      await _database.insert(
        'pending_avatar_uploads',
        upload.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    return upload;
  }

  Future<PendingAvatarUpload?> getForUser(String userId) async {
    final rows = await _database.query(
      'pending_avatar_uploads',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return rows.isEmpty ? null : PendingAvatarUpload.fromMap(rows.single);
  }

  Future<PendingAvatarUpload?> getNextPending(String userId) async {
    final rows = await _database.query(
      'pending_avatar_uploads',
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, AvatarUploadStatus.pending.name.toUpperCase()],
      limit: 1,
    );
    return rows.isEmpty ? null : PendingAvatarUpload.fromMap(rows.single);
  }

  Future<int> markProcessing(PendingAvatarUpload upload) {
    return _update(
      upload,
      {
        'status': AvatarUploadStatus.processing.name.toUpperCase(),
        'attempt_count': upload.attemptCount + 1,
        'last_error': null,
        'updated_at': _now().toUtc().toIso8601String(),
      },
      expectedStatus: AvatarUploadStatus.pending,
    );
  }

  Future<int> markPending(
    PendingAvatarUpload upload, {
    required String error,
  }) {
    return _update(
      upload,
      {
        'status': AvatarUploadStatus.pending.name.toUpperCase(),
        'last_error': error,
        'updated_at': _now().toUtc().toIso8601String(),
      },
    );
  }

  Future<int> markFailed(
    PendingAvatarUpload upload, {
    required String error,
  }) {
    return _update(
      upload,
      {
        'status': AvatarUploadStatus.failed.name.toUpperCase(),
        'last_error': error,
        'updated_at': _now().toUtc().toIso8601String(),
      },
    );
  }

  Future<int> retryFailed(String userId) {
    return runStorageWrite('failed avatar upload retry', () {
      return _database.update(
        'pending_avatar_uploads',
        {
          'status': AvatarUploadStatus.pending.name.toUpperCase(),
          'last_error': null,
          'updated_at': _now().toUtc().toIso8601String(),
        },
        where: 'user_id = ? AND status = ?',
        whereArgs: [userId, AvatarUploadStatus.failed.name.toUpperCase()],
      );
    });
  }

  Future<int> recoverProcessing(String userId) {
    return runStorageWrite('avatar upload recovery', () {
      return _database.update(
        'pending_avatar_uploads',
        {
          'status': AvatarUploadStatus.pending.name.toUpperCase(),
          'updated_at': _now().toUtc().toIso8601String(),
        },
        where: 'user_id = ? AND status = ?',
        whereArgs: [
          userId,
          AvatarUploadStatus.processing.name.toUpperCase(),
        ],
      );
    });
  }

  Future<int> deleteIfCurrent(PendingAvatarUpload upload) {
    return runStorageWrite('completed avatar upload removal', () {
      return _database.delete(
        'pending_avatar_uploads',
        where: 'id = ? AND user_id = ? AND local_path = ?',
        whereArgs: [upload.id, upload.userId, upload.localPath],
      );
    });
  }

  Future<int> _update(
    PendingAvatarUpload upload,
    Map<String, Object?> values, {
    AvatarUploadStatus? expectedStatus,
  }) {
    final statusClause = expectedStatus == null ? '' : ' AND status = ?';
    final statusArgs = expectedStatus == null
        ? const <Object?>[]
        : [expectedStatus.name.toUpperCase()];
    return runStorageWrite('pending avatar upload update', () {
      return _database.update(
        'pending_avatar_uploads',
        values,
        where: 'id = ? AND user_id = ? AND local_path = ?$statusClause',
        whereArgs: [
          upload.id,
          upload.userId,
          upload.localPath,
          ...statusArgs,
        ],
      );
    });
  }
}
