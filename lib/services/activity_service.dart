import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/activity.dart';
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
  ActivityService({AuthService? authService})
      : _authService = authService ?? AuthService();

  final AuthService _authService;

  Future<RecommendationBatch> getRecommendations({
    required double lat,
    required double lon,
    double radiusKm = 5,
    String timezone = 'America/Bogota',
  }) async {
    final response = await _authService.authenticatedRequest(
      method: 'GET',
      path:
      '/activities/recommendations?lat=$lat&lon=$lon&radius=$radiusKm'
          '&tz=${Uri.encodeQueryComponent(timezone)}',
    );
    _check(response, 'load the recommendations');

    final freeMinutes = int.tryParse(
      response.headers['x-free-time-minutes'] ?? '',
    );
    final recommendationId = response.headers['x-recommendation-id'];

    final items = _decodeList(response.body);
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

    return _decodeList(response.body)
        .map((item) => Activity.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
  }

  Future<void> join(
      String activityId, {
        String? recommendationId,
        int? freeTimeMinutes,
      }) async {
    final query = <String, String>{};
    if (recommendationId != null) {
      query['recommendationId'] = recommendationId;
    }
    if (freeTimeMinutes != null) {
      query['freeTimeMinutes'] = '$freeTimeMinutes';
    }
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