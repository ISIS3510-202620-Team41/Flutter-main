import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:llamalla/services/activity_service.dart';
import 'package:llamalla/services/auth_service.dart';

class _FakeAuthService extends AuthService {
  final Map<int, http.Response> pageResponses = {};
  final List<String> requestedPaths = [];
  final List<String> requestedMethods = [];
  String? requestedPath;
  http.Response requestResponse = http.Response('', 204);

  @override
  Future<http.Response> authenticatedCachedGet({
    required String path,
    Map<String, String>? headers,
  }) async {
    requestedPaths.add(path);
    final page = int.parse(Uri.parse(path).queryParameters['page']!);
    return pageResponses[page]!;
  }

  @override
  Future<http.Response> authenticatedRequest({
    required String method,
    required String path,
    Map<String, String>? headers,
    Object? body,
  }) async {
    requestedMethods.add(method);
    requestedPath = path;
    return requestResponse;
  }
}

Map<String, dynamic> _joinedItem(String id) {
  return {
    'activity': {
      'id': id,
      'title': 'Actividad $id',
      'description': 'Descripción',
      'category': 'CULTURA',
      'startTime': '2026-12-01T10:00:00Z',
      'endTime': '2026-12-01T12:00:00Z',
      'durationMinutes': 120,
      'locationName': 'Campus',
      'latitude': 4.6,
      'longitude': -74.0,
      'distanceKm': null,
      'participants': 2,
      'capacity': 10,
      'price': null,
      'aboutLocation': null,
      'imageUrl': null,
      'joined': true,
    },
    'enrollment': {
      'id': 'enrollment-$id',
      'joinedAt': '2026-11-20T12:00:00Z',
      'status': 'CONFIRMED',
    },
  };
}

http.Response _pageResponse({
  required int page,
  required List<Map<String, dynamic>> content,
  required bool hasNext,
}) {
  return http.Response(
    jsonEncode({
      'content': content,
      'page': page,
      'size': 1,
      'totalElements': hasNext ? 2 : 2,
      'totalPages': 2,
      'hasNext': hasNext,
    }),
    200,
  );
}

void main() {
  late _FakeAuthService authService;
  late ActivityService activityService;

  setUp(() {
    authService = _FakeAuthService();
    activityService = ActivityService(authService: authService);
  });

  test('loads all authenticated joined-activity pages', () async {
    authService.pageResponses
      ..[0] = _pageResponse(
        page: 0,
        content: [_joinedItem('activity-1')],
        hasNext: true,
      )
      ..[1] = _pageResponse(
        page: 1,
        content: [_joinedItem('activity-2')],
        hasNext: false,
      );

    final result = await activityService.getJoinedActivities(
      userId: 'current-user',
    );

    expect(result.map((item) => item.activity.id), [
      'activity-1',
      'activity-2',
    ]);
    expect(result.every((item) => item.userId == 'current-user'), isTrue);
    expect(authService.requestedPaths, [
      '/activities/joined?page=0&size=50',
      '/activities/joined?page=1&size=50',
    ]);
    expect(
      authService.requestedPaths.every(
        (path) => !Uri.parse(path).queryParameters.containsKey('userId'),
      ),
      isTrue,
    );
  });

  test('rejects a response with a mismatched page number', () async {
    authService.pageResponses[0] = _pageResponse(
      page: 1,
      content: [_joinedItem('activity-1')],
      hasNext: false,
    );

    await expectLater(
      activityService.getJoinedActivities(userId: 'current-user'),
      throwsA(isA<ActivityException>()),
    );
  });

  test('leaves through the backend DELETE endpoint', () async {
    authService.requestResponse = http.Response('', 404);

    await activityService.leave('activity-1');

    expect(authService.requestedMethods, ['DELETE']);
    expect(authService.requestedPath, '/activities/activity-1/leave');
  });
}
