import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:llamalla/database/app_database.dart';
import 'package:llamalla/database/local_database_facade.dart';
import 'package:llamalla/services/local_database_service.dart';
import 'package:llamalla/services/storage_capacity_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  late LocalDatabaseService service;

  setUp(() async {
    service = await LocalDatabaseService.open(
      database: AppDatabase(
        databaseFactory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      ),
    );
  });

  tearDown(() async {
    await service.close();
  });

  test('initializes all repositories', () {
    expect(service.activities, isNotNull);
    expect(service.preferences, isNotNull);
    expect(service.pendingActions, isNotNull);
  });

  test('shares the facade capacity coordinator with the database service', () {
    expect(
      identical(
        service.storageCapacity,
        LocalDatabaseFacade.instance.storageCapacity,
      ),
      isTrue,
    );
    expect(
      identical(service.storageCapacity, StorageCapacityService.shared),
      isTrue,
    );
  });

  test('uses a shared database connection', () async {
    final db = await service.database.database;

    expect(db.isOpen, isTrue);
  });

  test('closes the database connection', () async {
    final db = await service.database.database;

    await service.close();

    expect(db.isOpen, isFalse);
  });
}
