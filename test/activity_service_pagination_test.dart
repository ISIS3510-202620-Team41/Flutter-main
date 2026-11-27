import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:llamalla/database/app_database.dart';
import 'package:llamalla/repositories/activity_local_repository.dart';
import 'package:llamalla/services/activity_service.dart';
import 'package:llamalla/services/auth_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _PaginatedNearbyAuthService extends AuthService {
  final paths = <String>[];

  @override
  Future<http.Response> authenticatedCachedGet({
    required String path,
    Map<String, String>? headers,
  }) async {
    paths.add(path);
    final page = int.parse(
      Uri.parse('https://example.test$path').queryParameters['page']!,
    );
    final hasNext = page == 0;
    return http.Response(
      jsonEncode({
        'content': [
          {
            'id': 'activity-$page',
            'title': 'Activity $page',
            'category': 'SPORTS',
            'startTime': '2026-11-30T17:00:00Z',
            'endTime': '2026-11-30T18:00:00Z',
            'locationName': 'North Hall',
            'latitude': 4.6,
            'longitude': -74.0,
            'distanceKm': 0.1,
            'participants': 2,
            'capacity': 12,
            'price': 'Gratis',
          },
        ],
        'page': page,
        'size': 50,
        'totalElements': 2,
        'totalPages': 2,
        'hasNext': hasNext,
      }),
      200,
    );
  }
}

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase appDatabase;
  late ActivityLocalRepository localRepository;
  late _PaginatedNearbyAuthService authService;

  setUp(() async {
    appDatabase = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    localRepository = ActivityLocalRepository(await appDatabase.database);
    authService = _PaginatedNearbyAuthService();
  });

  tearDown(() async {
    await localRepository.dispose();
    await appDatabase.close();
  });

  test('loads and persists every BE-1 page', () async {
    final service = ActivityService(
      authService: authService,
      localRepository: localRepository,
    );

    await service.refreshNearby(lat: 4.6, lon: -74.0, radiusKm: 10);

    expect(authService.paths, hasLength(2));
    expect(
      authService.paths.map(
        (path) => Uri.parse('https://example.test$path').queryParameters,
      ),
      everyElement(containsPair('size', '50')),
    );
    expect(
      authService.paths
          .map(
            (path) =>
                Uri.parse('https://example.test$path').queryParameters['page'],
          )
          .toList(),
      ['0', '1'],
    );
    expect(
      (await service.getCachedActivityRecords()).map((record) => record.id),
      ['activity-0', 'activity-1'],
    );
  });
}
