import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:llamalla/services/analytics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('decodes the UUID subject from an access token', () {
    final payload = base64Url
        .encode(utf8.encode(jsonEncode({'sub': 'user-uuid'})))
        .replaceAll('=', '');
    final token = 'header.$payload.signature';

    expect(AnalyticsService().decodeUserId(token), 'user-uuid');
    expect(AnalyticsService().decodeUserId('not-a-token'), isNull);
  });

  test('persists and removes events after a successful batch', () async {
    SharedPreferences.setMockInitialValues({});
    final client = MockClient((request) async {
      expect(request.url.path, '/events/batch');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect((body['events'] as List).single['userId'], 'user-uuid');
      return http.Response('{}', 201);
    });
    final service = AnalyticsService(client: client);

    await service.initialize();
    service.setUserId('user-uuid');
    await service.track('screen_view', {'screen': 'Home'});
    await service.flush();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList('analytics_event_queue'), isEmpty);
  });

  test('retains events when the engine returns a server error', () async {
    SharedPreferences.setMockInitialValues({});
    final client = MockClient((_) async => http.Response('{}', 503));
    final service = AnalyticsService(client: client);

    await service.initialize();
    service.setUserId('user-uuid');
    await service.track('screen_view', {'screen': 'Home'});
    await service.flush();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList('analytics_event_queue'), hasLength(1));
  });

  test('moves persisted crashes into the event queue on startup', () async {
    SharedPreferences.setMockInitialValues({
      'analytics_pending_crashes': [
        jsonEncode({'screen': 'ActivityDetail', 'exceptionType': 'TestError'}),
      ],
    });
    final service = AnalyticsService();

    await service.initialize();

    final preferences = await SharedPreferences.getInstance();
    final events = preferences.getStringList('analytics_event_queue');
    expect(events, hasLength(1));
    expect(jsonDecode(events!.single)['eventType'], 'crash');
    expect(preferences.getStringList('analytics_pending_crashes'), isNull);
  });
}
