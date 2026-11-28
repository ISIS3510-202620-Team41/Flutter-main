import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:llamalla/database/app_database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  late AppDatabase appDatabase;

  setUp(() {
    appDatabase = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
  });

  tearDown(() async {
    await appDatabase.close();
  });

  test('initializes all required database tables', () async {
    final db = await appDatabase.database;

    final result = await db.rawQuery('''
      SELECT name
      FROM sqlite_master
      WHERE type = 'table'
      AND name NOT LIKE 'sqlite_%'
      ''');

    final tableNames = result.map((row) => row['name'] as String).toSet();

    expect(
      tableNames,
      containsAll({
        'activities',
        'user_preferences',
        'pending_actions',
        'joined_activities',
        'pending_avatar_uploads',
      }),
    );
  });

  test('reuses the same database connection', () async {
    final firstConnection = await appDatabase.database;
    final secondConnection = await appDatabase.database;

    expect(identical(firstConnection, secondConnection), isTrue);
  });

  test('can close and reopen the database', () async {
    final firstConnection = await appDatabase.database;

    await appDatabase.close();

    final secondConnection = await appDatabase.database;

    expect(identical(firstConnection, secondConnection), isFalse);
  });

  test(
    'adds joined activities when upgrading from database version 2',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'llamalla-db-migration-',
      );
      final path = p.join(directory.path, 'legacy.db');

      try {
        final oldDatabase = await databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: 2,
            onCreate: (db, _) async {
              await db.execute(
                'CREATE TABLE migration_marker (value TEXT NOT NULL)',
              );
              await db.insert('migration_marker', {'value': 'preserved'});
              await db.execute('''
              CREATE TABLE pending_actions (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                action_type TEXT NOT NULL,
                activity_id TEXT NOT NULL,
                payload_json TEXT NOT NULL,
                status TEXT NOT NULL,
                attempts INTEGER NOT NULL,
                last_error TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
              )
            ''');
              await db.insert('pending_actions', {
                'id': 'pending-join',
                'user_id': 'user-a',
                'action_type': 'JOIN_ACTIVITY',
                'activity_id': 'activity-1',
                'payload_json': '{}',
                'status': 'PENDING',
                'attempts': 0,
                'created_at': '2026-11-20T12:00:00Z',
                'updated_at': '2026-11-20T12:00:00Z',
              });
            },
          ),
        );
        await oldDatabase.close();

        final upgradedDatabase = AppDatabase(
          databaseFactory: databaseFactoryFfi,
          databasePath: path,
        );
        final database = await upgradedDatabase.database;
        final marker = await database.query('migration_marker');
        final joinedTable = await database.rawQuery('''
        SELECT name
        FROM sqlite_master
        WHERE type = 'table' AND name = 'joined_activities'
        ''');
        final migratedEnrollment = await database.query('joined_activities');

        expect(marker.single['value'], 'preserved');
        expect(joinedTable, hasLength(1));
        expect(migratedEnrollment.single['user_id'], 'user-a');
        expect(migratedEnrollment.single['enrollment_status'], 'PENDING_JOIN');
        await upgradedDatabase.close();
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'creates the avatar queue when upgrading from database version 3',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'llamalla-avatar-migration-',
      );
      final path = p.join(directory.path, 'legacy.db');

      try {
        final oldDatabase = await databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: 3,
            onCreate: (db, _) async {
              await db.execute(
                'CREATE TABLE migration_marker (value TEXT NOT NULL)',
              );
              await db.insert('migration_marker', {'value': 'preserved'});
            },
          ),
        );
        await oldDatabase.close();

        final upgradedDatabase = AppDatabase(
          databaseFactory: databaseFactoryFfi,
          databasePath: path,
        );
        final database = await upgradedDatabase.database;
        final marker = await database.query('migration_marker');
        final avatarTable = await database.rawQuery('''
        SELECT name
        FROM sqlite_master
        WHERE type = 'table' AND name = 'pending_avatar_uploads'
        ''');

        expect(marker.single['value'], 'preserved');
        expect(avatarTable, hasLength(1));
        await upgradedDatabase.close();
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'preserves an existing avatar queue when upgrading from database version 3',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'llamalla-avatar-migration-',
      );
      final path = p.join(directory.path, 'legacy.db');

      try {
        final oldDatabase = await databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: 3,
            onCreate: (db, _) async {
              await db.execute('''
                CREATE TABLE pending_avatar_uploads (
                  id TEXT PRIMARY KEY,
                  user_id TEXT NOT NULL UNIQUE,
                  local_path TEXT NOT NULL,
                  status TEXT NOT NULL DEFAULT 'PENDING'
                    CHECK(status IN ('PENDING', 'PROCESSING', 'FAILED')),
                  attempt_count INTEGER NOT NULL DEFAULT 0,
                  last_error TEXT,
                  created_at TEXT NOT NULL,
                  updated_at TEXT NOT NULL
                )
              ''');
              await db.insert('pending_avatar_uploads', {
                'id': 'upload-1',
                'user_id': 'user-a',
                'local_path': '/tmp/avatar.jpg',
                'created_at': '2026-11-20T12:00:00Z',
                'updated_at': '2026-11-20T12:00:00Z',
              });
            },
          ),
        );
        await oldDatabase.close();

        final upgradedDatabase = AppDatabase(
          databaseFactory: databaseFactoryFfi,
          databasePath: path,
        );
        final database = await upgradedDatabase.database;
        final uploads = await database.query('pending_avatar_uploads');

        expect(uploads, hasLength(1));
        expect(uploads.single['id'], 'upload-1');
        expect(uploads.single['user_id'], 'user-a');
        await upgradedDatabase.close();
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
}
