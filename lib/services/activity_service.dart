import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:llamalla/repositories/activity_local_repository.dart';

import '../database/local_database_facade.dart';
import '../utils/haversine.dart';
import '../utils/distance_calculator.dart';
import '../models/activity.dart';
import '../models/activity_record.dart';
import 'activity_image_cache_service.dart';
import 'auth_service.dart';

class ActivityException implements Exception {
  const ActivityException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class RecommendationBatch {
  const RecommendationBatch({
    required this.activities,
    this.recommendationId,
    this.freeMinutes,
  });

  final List<Activity> activities;
  final String? recommendationId;
  final int? freeMinutes;
}

class ActivityService {
  ActivityService({
    AuthService? authService,
    ActivityLocalRepository? localRepository,
    }): _authService = authService ?? AuthService(),
        _injectedLocalRepository = localRepository;

  final AuthService _authService;
  final ActivityLocalRepository? _injectedLocalRepository;
  final ActivityImageCacheService _imageCache = ActivityImageCacheService();
  
  ActivityLocalRepository? get _localRepository =>
    _injectedLocalRepository ?? LocalDatabaseFacade.instance.activities;


  Future<RecommendationBatch> getRecommendations({
    required double lat,
    required double lon,
    double radiusKm = 50,
    String timezone = 'America/Bogota',
    String networkQuality = 'unknown',
    bool calculateDistanceLocally = true,
  }) async {
    final response = await _authService.authenticatedCachedGet(
      path:
          '/activities/recommendations?lat=$lat&lon=$lon&radius=$radiusKm'
          '&tz=${Uri.encodeQueryComponent(timezone)}'
          '&networkQuality=$networkQuality',
    );

    _check(response, 'load the recommendations');

    final freeMinutes = int.tryParse(
      response.headers['x-free-time-minutes'] ?? '',
    );

    final recommendationId =
        response.headers['x-recommendation-id'];

    final items = _decodeList(response.body);

    // Pasamos al modelo de ActivityRecord
    final records = items.map((item) {
      final map = Map<String, dynamic>.from(item as Map);

      final activityJson =
          Map<String, dynamic>.from(map['activity'] as Map);

      return ActivityRecord.fromJson(activityJson);
    }).toList(growable: false);

    await _cacheActivities(records);

    // Procesamos distancias y radio en el isolate.
    final processedRecords = calculateDistanceLocally
        ? await DistanceCalculator.process(
            records: records,
            userLat: lat,
            userLon: lon,
            radiusKm: radiusKm,
            filterByRadius: true,
            sortByDistance: false,
          )
        : records;

    final recordsById = {
      for (final record in processedRecords)
        record.id: record,
    };

    final activities = <Activity>[];

    // Se conserva el score y orden de la recomendacion
    for (final item in items) {
      final map = Map<String, dynamic>.from(item as Map);

      final activityJson =
          Map<String, dynamic>.from(map['activity'] as Map);

      final originalRecord =
          ActivityRecord.fromJson(activityJson);

      final record = recordsById[originalRecord.id];

      // Puede no existir porque fue descartada por el radio.
      if (record == null) {
        continue;
      }

      activities.add(
        record.toActivity(
          score: (map['score'] as num?)?.toDouble(),
          freeMinutes: freeMinutes,
          calculatedDistanceKm:
              calculateDistanceLocally
                  ? record.distanceKm
                  : null,
          recalculateDistance: calculateDistanceLocally,
        ),
      );
    }

    return RecommendationBatch(
      activities: activities,
      recommendationId: recommendationId,
      freeMinutes: freeMinutes,
    );
  }

  Future<List<Activity>> getNearby({
    required double lat,
    required double lon,
    double radiusKm = 50,
    bool calculateDistanceLocally = true,
  }) async {
    final records = await _fetchNearbyRecords(
      lat: lat,
      lon: lon,
      radiusKm: radiusKm,
    );

    await _cacheActivities(records);

    return _mapRecordsToActivities(
      records,
      lat: calculateDistanceLocally ? lat : null,
      lon: calculateDistanceLocally ? lon : null,
      radiusKm: radiusKm,
    );
  }

  Future<void> refreshNearby({
    required double lat,
    required double lon,
    double radiusKm = 50,
  }) async {
    final records = await _fetchNearbyRecords(
      lat: lat,
      lon: lon,
      radiusKm: radiusKm,
    );

    await _cacheActivities(records);
  }

  Future<ActivityRecord?> getCachedActivityById(String id) async {
    final repository = _localRepository;

    if (repository == null) {
      return null;
    }

    return repository.getById(id);
  }

  Future<ActivityRecord> getActivityById(String id) async {
    final response = await _authService.authenticatedCachedGet(
      path: '/activities/${Uri.encodeComponent(id)}',
    );

    _check(response, 'load the activity');

    final decoded = jsonDecode(response.body);

    if (decoded is! Map) {
      throw const ActivityException('Invalid server response');
    }

    final record = ActivityRecord.fromJson(
      Map<String, dynamic>.from(decoded),
    );

    // Guardamos la actividad y descargamos su imagen.
    await _cacheActivities([record]);

    // Recuperamos desde SQLite la versión que ya contiene localImagePath.
    final cachedRecord = await _localRepository?.getById(id);

    return cachedRecord ?? record;
  }

  Future<List<Activity>> getPendingActivities() async {
    final repository = _localRepository;
    if (repository == null) return [];

    final records = await repository.getPendingSync();
    return records.map((record) => record.toActivity()).toList(growable: false);
  }
  Future<Activity> createActivity(
      Map<String, dynamic> body, {
        String? source,
      }) async {
    final query = source == null ? '' : '?source=$source';
    final response = await _authService.authenticatedRequest(
      method: 'POST',
      path: '/activities$query',
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    _check(response, 'create the activity');

    final record = ActivityRecord.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
    await _cacheActivities([record]);
    return record.toActivity();
  }

  Future<void> join(
      String activityId, {
        String? recommendationId,
        int? freeTimeMinutes,
        String? networkQuality,
        String? source,
      }) async {
    final query = <String, String>{};
    if (recommendationId != null) query['recommendationId'] = recommendationId;
    if (freeTimeMinutes != null) query['freeTimeMinutes'] = '$freeTimeMinutes';
    if (networkQuality != null) query['networkQuality'] = networkQuality;
    if (source != null) query['source'] = source;
    final queryString =
    query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';

    final response = await _authService.authenticatedRequest(
      method: 'POST',
      path: '/activities/$activityId/join$queryString',
    );
    _check(response, 'join the activity');
  }

  Future<List<Activity>> _mapRecordsToActivities(
    List<ActivityRecord> records, {
    double? lat,
    double? lon,
    double radiusKm = 50,
  }) async {
    // No location valid no calculamos distancias
    if (lat == null || lon == null) {
      return records
          .map(
            (record) => record.toActivity(
              recalculateDistance: true,
            ),
          )
          .toList(growable: false);
    }

    // Procesamos todo el lote en el isolate.
    final processedRecords = await DistanceCalculator.process(
      records: records,
      userLat: lat,
      userLon: lon,
      radiusKm: radiusKm,
      filterByRadius: true,
      sortByDistance: true,
    );

    // ActivityService recibe los registros ya procesados.
    return processedRecords.map((record) {
      return record.toActivity(
        calculatedDistanceKm: record.distanceKm,
        recalculateDistance: true,
      );
    }).toList(growable: false);
  }

  List<dynamic> _decodeList(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! List) {
      throw const ActivityException('Invalid server response');
    }
    return decoded;
  }

  Future<List<Activity>> getCachedActivities({
    double? lat,
    double? lon,
    double radiusKm = 50,
  }) async {
    final repository = _localRepository;

    if (repository == null) {
      return [];
    }

    final records = await repository.getAll();

    return _mapRecordsToActivities(
      records,
      lat: lat,
      lon: lon,
      radiusKm: radiusKm,
    );
  }

  Stream<List<Activity>> watchCachedActivities({double? lat, double? lon, double radiusKm = 50,}) {
    final repository = _localRepository;

    if (repository == null) {
      return Stream.value(const <Activity>[]);
    }

    return repository.watchAll().asyncMap((records) {
      return _mapRecordsToActivities(
        records,
        lat: lat,
        lon: lon,
        radiusKm: radiusKm,
      );
    });
  }

  Future<void> _cacheActivities(
    List<ActivityRecord> records,
  ) async {
    final repository = _localRepository;

    if (repository == null || records.isEmpty) {
      return;
    }

    try {
      final updatedRecords = <ActivityRecord>[];

      for (final record in records) {
        final previous = await repository.getById(record.id);

        String? localPath = previous?.localImagePath;

        final imageUrl = record.imageUrl?.trim() ?? '';

        if (imageUrl.isNotEmpty) {
          final downloadedPath = await _imageCache.downloadAndCache(
            activityId: record.id,
            imageUrl: imageUrl,
          );

          if (downloadedPath != null) {
            localPath = downloadedPath;
          }
        }

        updatedRecords.add(
          record.copyWith(localImagePath: localPath),
        );
      }

      await repository.upsertAll(updatedRecords);
    } catch (_) { 
    }
  }

  Future<List<ActivityRecord>> _fetchNearbyRecords({
    required double lat,
    required double lon,
    required double radiusKm,
  }) async {
    final response = await _authService.authenticatedCachedGet(
      path: '/activities?lat=$lat&lon=$lon&radius=$radiusKm',
    );

    _check(response, 'load nearby activities');

    return _decodeList(response.body)
        .map(
          (item) => ActivityRecord.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  void _check(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    var message = 'It was not possible $action.';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['message'] is String) {
        message = decoded['message'] as String;
      }
    } on FormatException {
      // Use the generic message when the backend response is not JSON.
    }
    throw ActivityException(message, statusCode: response.statusCode);
  }
}