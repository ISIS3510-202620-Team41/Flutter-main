import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:llamalla/repositories/activity_local_repository.dart';

import '../database/local_database_facade.dart';
import '../utils/distance_calculator.dart';
import '../models/activity.dart';
import '../models/activity_record.dart';
import '../models/joined_activity_record.dart';
import 'activity_image_cache_service.dart';
import 'auth_service.dart';
import '../models/activity_draft.dart';
import 'storage_write_error.dart';
import '../utils/haversine.dart';

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
  static const _nearbyPageSize = 50;

  ActivityService({
    AuthService? authService,
    ActivityLocalRepository? localRepository,
    ActivityImageCacheService? imageCache,
  }) : _authService = authService ?? AuthService(),
       _injectedLocalRepository = localRepository,
       _imageCache = imageCache ?? ActivityImageCacheService();

  final AuthService _authService;
  final ActivityLocalRepository? _injectedLocalRepository;
  final ActivityImageCacheService _imageCache;

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

    final recommendationId = response.headers['x-recommendation-id'];

    final items = _decodeList(response.body);

    // Pasamos al modelo de ActivityRecord
    final records = items
        .map((item) {
          final map = Map<String, dynamic>.from(item as Map);

          final activityJson = Map<String, dynamic>.from(
            map['activity'] as Map,
          );

          return ActivityRecord.fromJson(activityJson);
        })
        .toList(growable: false);

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
      for (final record in processedRecords) record.id: record,
    };

    final activities = <Activity>[];

    // Se conserva el score y orden de la recomendacion
    for (final item in items) {
      final map = Map<String, dynamic>.from(item as Map);

      final activityJson = Map<String, dynamic>.from(map['activity'] as Map);

      final originalRecord = ActivityRecord.fromJson(activityJson);

      final record = recordsById[originalRecord.id];

      // Puede no existir porque fue descartada por el radio.
      if (record == null) {
        continue;
      }

      activities.add(
        record.toActivity(
          score: (map['score'] as num?)?.toDouble(),
          freeMinutes: freeMinutes,
          calculatedDistanceKm: calculateDistanceLocally
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

  Future<List<JoinedActivityRecord>> getJoinedActivities({
    required String userId,
  }) async {
    final joined = <JoinedActivityRecord>[];
    var page = 0;

    while (true) {
      final response = await _authService.authenticatedCachedGet(
        path: '/activities/joined?page=$page&size=$_nearbyPageSize',
      );
      _check(response, 'load joined activities');

      final decoded = jsonDecode(response.body);
      if (decoded is! Map ||
          decoded['content'] is! List ||
          decoded['page'] is! num ||
          decoded['hasNext'] is! bool ||
          (decoded['page'] as num).toInt() != page) {
        throw const ActivityException(
          'Invalid paginated joined activity response.',
        );
      }

      final content = decoded['content'] as List;
      if (content.isEmpty && decoded['hasNext'] == true) {
        throw const ActivityException(
          'Joined activity pagination returned an empty page with more results.',
        );
      }

      try {
        joined.addAll(
          content.map(
            (item) => JoinedActivityRecord.fromRemoteJson(item, userId: userId),
          ),
        );
      } on FormatException catch (error) {
        throw ActivityException(
          'Invalid joined activity data: ${error.message}',
        );
      }

      if (decoded['hasNext'] != true) break;
      page++;
    }

    return joined;
  }

  //Step 3: los lugares donde ya hay actividades cerca
  Future<List<PlaceOption>> getNearbyPlaces({
    required double lat,
    required double lon,
    double radiusKm = 50,
  }) async {
    final records = await _fetchNearbyRecords(
      lat: lat,
      lon: lon,
      radiusKm: radiusKm,
    );

    final withDistance =
        records.map((record) {
          final km =
              record.distanceKm ??
              Haversine.calculateDistanceKm(
                latitude1: lat,
                longitude1: lon,
                latitude2: record.latitude,
                longitude2: record.longitude,
              );
          return (record: record, km: km);
        }).toList()..sort(
          (a, b) =>
              (a.km ?? double.infinity).compareTo(b.km ?? double.infinity),
        );

    final places = <String, PlaceOption>{};
    for (final item in withDistance) {
      final record = item.record;
      if (places.containsKey(record.locationName)) continue;

      final start = DateTime.tryParse(record.startTime);
      final end = DateTime.tryParse(record.endTime);
      final minutes = (start != null && end != null)
          ? end.difference(start).inMinutes
          : 60;

      places[record.locationName] = PlaceOption(
        name: record.locationName,
        distance: _distanceLabel(item.km),
        durationMinutes: minutes > 0 ? minutes : 60,
        price: record.price ?? '',
        latitude: record.latitude,
        longitude: record.longitude,
        capacity: record.capacity ?? 10,
        description: record.aboutLocation ?? '',
        imageUrl: record.imageUrl ?? '',
      );
    }
    return places.values.toList(growable: false);
  }

  String _distanceLabel(double? km) {
    if (km == null) return '';
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
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

    final record = ActivityRecord.fromJson(Map<String, dynamic>.from(decoded));

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
    final queryString = query.isEmpty
        ? ''
        : '?${Uri(queryParameters: query).query}';

    final response = await _authService.authenticatedRequest(
      method: 'POST',
      path: '/activities/$activityId/join$queryString',
    );
    _check(response, 'join the activity');
  }

  Future<void> leave(String activityId) async {
    final response = await _authService.authenticatedRequest(
      method: 'DELETE',
      path: '/activities/$activityId/leave',
    );
    if (response.statusCode == 404) return;
    _check(response, 'leave the activity');
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
          .map((record) => record.toActivity(recalculateDistance: true))
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
    return processedRecords
        .map((record) {
          return record.toActivity(
            calculatedDistanceKm: record.distanceKm,
            recalculateDistance: true,
          );
        })
        .toList(growable: false);
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

  Future<List<ActivityRecord>> getCachedActivityRecords() async {
    final repository = _localRepository;
    if (repository == null) return const [];
    return repository.getAll();
  }

  Stream<List<Activity>> watchCachedActivities({
    double? lat,
    double? lon,
    double radiusKm = 50,
  }) {
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

  Future<void> _cacheActivities(List<ActivityRecord> records) async {
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

        updatedRecords.add(record.copyWith(localImagePath: localPath));
      }

      await repository.upsertAll(updatedRecords);
    } on StorageWriteException {
      // Activity cache persistence is optional; the failure was already reported.
    } catch (error, stackTrace) {
      reportStorageFailure(
        StorageWriteException(
          kind: classifyStorageFailure(error),
          operation: 'activity cache persistence',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  Future<List<ActivityRecord>> _fetchNearbyRecords({
    required double lat,
    required double lon,
    required double radiusKm,
  }) async {
    final records = <ActivityRecord>[];
    var page = 0;

    while (true) {
      final response = await _authService.authenticatedCachedGet(
        path:
            '/activities?lat=$lat&lon=$lon&radius=$radiusKm'
            '&page=$page&size=$_nearbyPageSize',
      );
      _check(response, 'load nearby activities');

      final decoded = jsonDecode(response.body);
      if (decoded is! Map ||
          decoded['content'] is! List ||
          decoded['page'] is! num ||
          decoded['hasNext'] is! bool ||
          (decoded['page'] as num).toInt() != page) {
        throw const ActivityException('Invalid paginated activity response.');
      }

      final content = decoded['content'] as List;
      if (content.isEmpty && decoded['hasNext'] == true) {
        throw const ActivityException(
          'Activity pagination returned an empty page with more results.',
        );
      }

      records.addAll(
        content.map(
          (item) =>
              ActivityRecord.fromJson(Map<String, dynamic>.from(item as Map)),
        ),
      );

      if (decoded['hasNext'] != true) break;
      page++;
    }

    return records;
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
      // Error porque el mensaje no esta en JSON
    }
    throw ActivityException(message, statusCode: response.statusCode);
  }
}
