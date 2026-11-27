import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:llamalla/database/app_database.dart';
import 'package:llamalla/models/activity_record.dart';
import 'package:llamalla/models/storage_capacity.dart';
import 'package:llamalla/repositories/activity_local_repository.dart';
import 'package:llamalla/services/activity_service.dart';
import 'package:llamalla/services/auth_service.dart';
import 'package:llamalla/services/storage_write_error.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _DiskFullDatabaseException extends DatabaseException {
  _DiskFullDatabaseException() : super('database or disk is full');

  @override
  int? getResultCode() => 13;

  @override
  Object? get result => null;
}

class _FailingActivityLocalRepository extends ActivityLocalRepository {
  _FailingActivityLocalRepository(super.database);

  @override
  Future<void> upsertAll(
    List<ActivityRecord> activities, {
    ActivityWritePolicy policy = ActivityWritePolicy.optionalCache,
  }) async {
    throw _DiskFullDatabaseException();
  }
}

class _ActivityResponseAuthService extends AuthService {
  @override
  Future<http.Response> authenticatedCachedGet({
    required String path,
    Map<String, String>? headers,
  }) async {
    return http.Response(
      jsonEncode({
        'id': 'activity-1',
        'title': 'Football',
        'category': 'SPORTS',
        'startTime': '2026-11-30T17:00:00Z',
        'endTime': '2026-11-30T19:00:00Z',
        'locationName': 'University courts',
        'latitude': 4.6382,
        'longitude': -74.084,
        'participants': 3,
      }),
      200,
    );
  }
}

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase appDatabase;
  late _FailingActivityLocalRepository localRepository;

  setUp(() async {
    appDatabase = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    localRepository = _FailingActivityLocalRepository(
      await appDatabase.database,
    );
  });

  tearDown(() async {
    await localRepository.dispose();
    await appDatabase.close();
  });

  test(
    'returns remote activity when its optional local cache write fails',
    () async {
      final reportedErrors = <FlutterErrorDetails>[];
      final previousErrorHandler = FlutterError.onError;
      FlutterError.onError = reportedErrors.add;

      try {
        final service = ActivityService(
          authService: _ActivityResponseAuthService(),
          localRepository: localRepository,
        );

        final activity = await service.getActivityById('activity-1');

        expect(activity.id, 'activity-1');
        expect(reportedErrors, hasLength(1));
        expect(reportedErrors.single.exception, isA<StorageWriteException>());
        expect(
          (reportedErrors.single.exception as StorageWriteException).kind,
          StorageFailureKind.capacity,
        );
      } finally {
        FlutterError.onError = previousErrorHandler;
      }
    },
  );
}
