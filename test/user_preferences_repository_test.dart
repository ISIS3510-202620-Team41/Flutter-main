import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:llamalla/database/app_database.dart';
import 'package:llamalla/models/user_preference.dart';
import 'package:llamalla/repositories/user_preferences_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  late AppDatabase appDatabase;
  late UserPreferencesRepository repository;

  setUp(() async {
    appDatabase = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );

    final db = await appDatabase.database;
    repository = UserPreferencesRepository(db);
  });

  tearDown(() async {
    await appDatabase.close();
  });

  final preference = UserPreference(
    id: 'preference-1',
    userId: 'user-1',
    category: 'DEPORTES',
    score: 0.85,
    cachedAt: DateTime.utc(2026, 10, 29),
  );

  test('creates and retrieves a preference', () async {
    await repository.insert(preference);

    final result = await repository.getById('preference-1');

    expect(result, isNotNull);
    expect(result!.userId, 'user-1');
    expect(result.score, 0.85);
  });

  test('retrieves preferences by user', () async {
    await repository.insert(preference);

    final result = await repository.getByUserId('user-1');
    final otherUser = await repository.getByUserId('user-2');

    expect(result.length, 1);
    expect(otherUser, isEmpty);
  });

  test('updates an existing preference', () async {
    await repository.insert(preference);

    final updated = UserPreference(
      id: preference.id,
      userId: preference.userId,
      category: preference.category,
      score: 0.95,
      cachedAt: DateTime.utc(2026, 10, 29),
    );

    final rows = await repository.update(updated);
    final result = await repository.getById(preference.id);

    expect(rows, 1);
    expect(result!.score, 0.95);
  });

  test('upserts a preference', () async {
    await repository.insert(preference);

    final updated = UserPreference(
      id: preference.id,
      userId: preference.userId,
      category: preference.category,
      score: 0.95,
      cachedAt: DateTime.utc(2026, 10, 29),
    );

    await repository.upsert(updated);

    final result = await repository.getById(preference.id);

    expect(result!.score, 0.95);
  });

  test('deletes preferences by user', () async {
    await repository.insert(preference);

    final rows = await repository.deleteByUserId('user-1');
    final result = await repository.getByUserId('user-1');

    expect(rows, 1);
    expect(result, isEmpty);
  });
}
