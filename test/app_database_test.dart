
import 'package:flutter_test/flutter_test.dart';
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

    final result = await db.rawQuery(
      '''
      SELECT name
      FROM sqlite_master
      WHERE type = 'table'
      AND name NOT LIKE 'sqlite_%'
      '''
    );

    final tableNames = result
        .map((row) => row['name'] as String)
        .toSet();

    expect(
      tableNames,
      containsAll({
        'activities',
        'user_preferences',
        'pending_actions',
      }),
    );
  });

  test('reuses the same database connection', () async {
    final firstConnection = await appDatabase.database;
    final secondConnection = await appDatabase.database;

    expect(
      identical(firstConnection, secondConnection),
      isTrue,
    );
  });

  test('can close and reopen the database', () async {
    final firstConnection = await appDatabase.database;

    await appDatabase.close();

    final secondConnection = await appDatabase.database;

    expect(
      identical(firstConnection, secondConnection),
      isFalse,
    );
  });
}
