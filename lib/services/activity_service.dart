import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:llamalla/repositories/activity_local_repository.dart';

import '../database/local_database_facade.dart';
import '../utils/haversine.dart';
import '../models/activity.dart';
import '../models/activity_record.dart';
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

  ActivityLocalRepository? get _localRepository =>
    _injectedLocalRepository ?? LocalDatabaseFacade.instance.activities;

  Future<RecommendationBatch> getRecommendations({
    required double lat,
    required double lon,
    double radiusKm = 5,
    String timezone = 'America/Bogota',
    bool calculateDistanceLocally = true,
    String networkQuality = 'unknown',
  }) async {
    final response = await _authService.authenticatedCachedGet(
      path:
          '/activities/recommendations?lat=$lat&lon=$lon&radius=$radiusKm'
          '&tz=${Uri.encodeQueryComponent(timezone)}'
          '&networkQuality=$networkQuality',
          '/activities/recommendations?lat=$lat&lon=$lon&radius=$radiusKm'
          '&tz=${Uri.encodeQueryComponent(timezone)}',
    );

    _check(response, 'load the recommendations');

    final freeMinutes = int.tryParse(
      response.headers['x-free-time-minutes'] ?? '',
    );

    final recommendationId = response.headers['x-recommendation-id'];

    final items = _decodeList(response.body);

    final records = items.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      final activityJson =
          Map<String, dynamic>.from(map['activity'] as Map);

      return ActivityRecord.fromJson(activityJson);
    }).toList(growable: false);

    await _cacheActivities(records);

    final activities = items.map((item) {
      final map = Map<String, dynamic>.from(item as Map);

      final activityJson =
          Map<String, dynamic>.from(map['activity'] as Map);

      final record = ActivityRecord.fromJson(activityJson);

      final distanceKm = calculateDistanceLocally
          ? Haversine.calculateDistanceKm(
              latitude1: lat,
              longitude1: lon,
              latitude2: record.latitude,
              longitude2: record.longitude,
            )
          : null;

      return record.toActivity(
        score: (map['score'] as num?)?.toDouble(),
        freeMinutes: freeMinutes,
        calculatedDistanceKm: distanceKm,
        recalculateDistance: true,
      );
    }).toList(growable: false);

    return RecommendationBatch(
      activities: activities,
      recommendationId: recommendationId,
      freeMinutes: freeMinutes,
    );
  }

  Future<List<Activity>> getNearby({required double lat, required double lon, double radiusKm = 5, bool calculateDistanceLocally = true,}) async {
    final response = await _authService.authenticatedCachedGet(
      path: '/activities?lat=$lat&lon=$lon&radius=$radiusKm',
    );
    _check(response, 'load nearby activities');

    final records = _decodeList(response.body)
        .map((item) => ActivityRecord.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),)
        .toList(growable: false);

    await _cacheActivities(records);

    return _mapRecordsToActivities(
      records,
      lat: calculateDistanceLocally ? lat: null,
      lon: calculateDistanceLocally ? lon: null,
      radiusKm: radiusKm,
    );
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

    await _cacheActivities([record]);

    return record;
  }

  Future<List<Activity>> getPendingActivities() async {
    final repository = _localRepository;
    if (repository == null) return [];

    final records = await repository.getPendingSync();
    return records.map((record) => record.toActivity()).toList(growable: false);
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

  List<Activity> _mapRecordsToActivities(
    List<ActivityRecord> records, {double? lat, double? lon, double radiusKm = 5,}) {
    final hasLocation = lat != null && lon != null;
    final activities = <Activity>[];

    for (final record in records) {
      final distanceKm = hasLocation
          ? Haversine.calculateDistanceKm(
              latitude1: lat,
              longitude1: lon,
              latitude2: record.latitude,
              longitude2: record.longitude,
            )
          : null;

      if (hasLocation &&
          distanceKm != null &&
          distanceKm > radiusKm) {
        continue;
      }

      activities.add(
        record.toActivity(
          calculatedDistanceKm: distanceKm,
          recalculateDistance: true,
        ),
      );
    }

    return activities;
  }
  List<dynamic> _decodeList(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! List) {
      throw const ActivityException('Invalid server response');
    }
    return decoded;
  }

  Future<List<Activity>> getCachedActivities({double? lat, double? lon, double radiusKm =5, }) async {
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

  Future<void> _cacheActivities(List<ActivityRecord> records,) async {
    final repository = _localRepository;

    if (repository == null || records.isEmpty) {
      return;
    }

    try {
      await repository.upsertAll(records);
    } catch (_) {
    }
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