import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:llamalla/repositories/activity_local_repository.dart';

import '../database/local_database_facade.dart';
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
    String networkQuality = 'unknown',
  }) async {
    final response = await _authService.authenticatedRequest(
      method: 'GET',
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

    final records = items.map((item) {
    final map = Map<String, dynamic>.from(item as Map);
    final activityJson = Map<String, dynamic>.from(map['activity'] as Map);

    return ActivityRecord.fromJson(activityJson);
    }).toList(growable: false);

    await _cacheActivities(records);

    final activities = items.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return Activity.fromJson(
        Map<String, dynamic>.from(map['activity'] as Map),
        score: (map['score'] as num?)?.toDouble(),
        freeMinutes: freeMinutes,
      );
    }).toList(growable: false);

    return RecommendationBatch(
      activities: activities,
      recommendationId: recommendationId,
      freeMinutes: freeMinutes,
    );
  }

  Future<List<Activity>> getNearby({
    required double lat,
    required double lon,
    double radiusKm = 5,
  }) async {
    final response = await _authService.authenticatedRequest(
      method: 'GET',
      path: '/activities?lat=$lat&lon=$lon&radius=$radiusKm',
    );
    _check(response, 'load nearby activities');

    final records = _decodeList(response.body)
        .map((item) => ActivityRecord.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList(growable: false);

    await _cacheActivities(records);

    return records
        .map((record) => record.toActivity())
        .toList(growable: false);
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

  List<dynamic> _decodeList(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! List) {
      throw const ActivityException('Invalid server response');
    }
    return decoded;
  }

  Future<List<Activity>> getCachedActivities() async {
    final repository = _localRepository;

    if (repository == null) {
      return [];
    }

    final records = await repository.getAll();

    return records
        .map((record) => record.toActivity())
        .toList(growable: false);
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
  Future<Activity> createActivity(
      Map<String, dynamic> body, {
        String? source,
      }) async {
    final query = source == null ? '' : '?source=$source';
    final response = await _authService.authenticatedRequest(
      method: 'POST',
      path: '/activities$query',
      body: jsonEncode(body),
    );
    _check(response, 'create the activity');
    return Activity.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
  }
  Future<Activity?> getCachedActivity(String id) async {
    final record = await _localRepository?.getById(id);
    return record?.toActivity();
  }
}