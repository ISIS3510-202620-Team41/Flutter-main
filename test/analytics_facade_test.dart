import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:llamalla/analytics/analytics_facade.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:llamalla/analytics/http_analytics_ingestion_service.dart';

void main() {
  test('decodes the UUID subject from an access token', () {
    final payload = base64Url
        .encode(utf8.encode(jsonEncode({'sub': 'user-uuid'})))
        .replaceAll('=', '');
    final token = 'header.$payload.signature';

    expect(AnalyticsFacade().decodeUserId(token), 'user-uuid');
    expect(AnalyticsFacade().decodeUserId('not-a-token'), isNull);
  });

  test('persists and removes events after a successful batch', () async {
    SharedPreferences.setMockInitialValues({});
    
    final client = MockClient((request) async {
      expect(request.url.path, '/events/batch');
      
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final event = (body['events'] as List).single as Map<String, dynamic>;

      
      expect(event['userId'], 'user-uuid');
      expect(event['eventType'], 'screen_view');
      expect(event['screen'], 'Home');

      return http.Response('{}', 201);
    });
    final facade = AnalyticsFacade(
    ingestionService: HttpAnalyticsIngestionService(
    client: client,
  ),
);

    await facade.initialize();
    facade.setUserId('user-uuid');

    await facade.trackScreenView(screen: 'Home');
    await facade.flush();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList('analytics_event_queue'), isEmpty);
  });

  test('retains events when the engine returns a server error', () async {
    SharedPreferences.setMockInitialValues({});

    final client = MockClient((_) async => http.Response('{}', 503));
    final facade = AnalyticsFacade(
    ingestionService: HttpAnalyticsIngestionService(
    client: client,
  ),
);

    await facade.initialize();
    facade.setUserId('user-uuid');
    await facade.trackScreenView(screen: 'Home');
    await facade.flush();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList('analytics_event_queue'), hasLength(1));
  });

  test('moves persisted crashes into the event queue on startup', () async {
    SharedPreferences.setMockInitialValues({
      'analytics_pending_crashes': [
        jsonEncode({'screen': 'ActivityDetail', 'exceptionType': 'TestError'}),
      ],
    });
    final facade = AnalyticsFacade();

    await facade.initialize();

    final preferences = await SharedPreferences.getInstance();
    final events = preferences.getStringList('analytics_event_queue');
    expect(events, hasLength(1));
    expect(jsonDecode(events!.single)['eventType'], 'crash');
    expect(preferences.getStringList('analytics_pending_crashes'), isNull);
  });

  test('tracks feature usage through the facade API', () async {
    SharedPreferences.setMockInitialValues({});

    final facade = AnalyticsFacade();
    await facade.initialize();

    await facade.trackFeatureUsed(
      feature: 'friend_availability',
      action: 'check_availability',
      screen: 'FriendAvailability',
      );
    
    final preferences = await SharedPreferences.getInstance();
    final events = preferences.getStringList('analytics_event_queue');

    expect(events, hasLength(1));

    final event = jsonDecode(events!.single) as Map<String, dynamic>;

    expect(event['eventType'], 'feature_used');
    expect(event['feature'], 'friend_availability');
    expect(event['action'], 'check_availability');
    expect(event['screen'], 'FriendAvailability');
    expect(event['eventId'], isNotEmpty);
    expect(event['sessionId'], isNotEmpty);
    expect(event['appVersion'], isNotEmpty);
  });

  test('track app loading time in miliseconds', () async {
    SharedPreferences.setMockInitialValues({});

    final facade = AnalyticsFacade();
    await facade.initialize();

    await facade.trackAppLoadingTime(
      loadType: 'cold_start', 
      duration: const Duration(milliseconds: 125),
      );
    
    final preferences = await SharedPreferences.getInstance();
    final events = preferences.getStringList('analytics_event_queue');

    expect(events, hasLength(1));

    final event = jsonDecode(events!.single) as Map<String, dynamic>;

    expect(event['eventType'], 'app_loading_time');
    expect(event['loadType'], 'cold_start');
    expect(event['durationMs'], 125);
  });

  test('records crashes with the current screen context', () async {
    SharedPreferences.setMockInitialValues({});

    final facade = AnalyticsFacade();
    await facade.initialize();

    await facade.trackScreenView(screen: 'Profile');

    await facade.recordCrash(
      component: 'ProfileScreen',
      error: StateError('Test error'),
      );
    
    final preferences = await SharedPreferences.getInstance();
    final crashes = preferences.getStringList('analytics_pending_crashes');

    expect(crashes, hasLength(1));

    final crash = jsonDecode(crashes!.single) as Map<String, dynamic>;

    expect(crash['screen'], 'Profile');
    expect(crash['component'], 'ProfileScreen');
    expect(crash['exceptionType'], 'StateError');
  });

  for (final statusCode in <int>[401, 422]) {
    test('discards events when the engine returns HTTP $statusCode', () async {
      SharedPreferences.setMockInitialValues({});

      final client = MockClient(
          (_) async => http.Response('{}', statusCode),
        );
      final facade = AnalyticsFacade(
        ingestionService: HttpAnalyticsIngestionService(
        client: client,
      ),
    );

      await facade.initialize();
      facade.setUserId('user-uuid');

      await facade.trackScreenView(screen: 'Home');
      await facade.flush();

      final preferences = await SharedPreferences.getInstance();

      expect(preferences.getStringList('analytics_event_queue'), isEmpty,);
      },);
  }

  test('retains events on an unexpected HTTP error', () async {
    SharedPreferences.setMockInitialValues({});

    final client = MockClient(
      (_) async => http.Response('{}', 400),
    );
    final facade = AnalyticsFacade(
      ingestionService: HttpAnalyticsIngestionService(
      client: client,
      ),
    );

    await facade.initialize();
    facade.setUserId('user-uuid');

    await facade.trackScreenView(screen: 'Home');
    await facade.flush();

    final preferences = await SharedPreferences.getInstance();

    expect(
      preferences.getStringList('analytics_event_queue'),
      hasLength(1),
    );
  });

  test('sends retained events when the engine recovers', () async {
    SharedPreferences.setMockInitialValues({});

    final responses = <int>[503, 201];
    var requestCount = 0;

    final client = MockClient((_) async {
      final statusCode = responses[requestCount];
      requestCount++;

      return http.Response('{}', statusCode);
    });

    final facade = AnalyticsFacade(
  ingestionService: HttpAnalyticsIngestionService(
    client: client,
  ),
);

    await facade.initialize();
    facade.setUserId('user-uuid');

    await facade.trackScreenView(screen: 'Home');

    await facade.flush();

    var preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getStringList('analytics_event_queue'),
      hasLength(1),
    );

    await facade.flush();

    preferences = await SharedPreferences.getInstance();

    expect(requestCount, 2);
    expect(
      preferences.getStringList('analytics_event_queue'),
      isEmpty,
    );
  });

  test('sends no more than 200 events per batch', () async {
    SharedPreferences.setMockInitialValues({});

    final batchSizes = <int>[];

    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final events = body['events'] as List;

      batchSizes.add(events.length);

      return http.Response('{}', 201);
    });

    final facade = AnalyticsFacade(
  ingestionService: HttpAnalyticsIngestionService(
    client: client,
  ),
);

    await facade.initialize();
    facade.setUserId('user-uuid');

    for (var i = 0; i < 201; i++) {
      await facade.trackScreenView(screen: 'Screen$i');
    }

    await facade.flush();

    var preferences = await SharedPreferences.getInstance();

    expect(batchSizes, [200]);
    expect(
      preferences.getStringList('analytics_event_queue'),
      hasLength(1),
    );

    await facade.flush();

    preferences = await SharedPreferences.getInstance();

    expect(batchSizes, [200, 1]);
    expect(
      preferences.getStringList('analytics_event_queue'),
      isEmpty,
    );
  });

  test('does not send events without an identified user', () async {
    SharedPreferences.setMockInitialValues({});

    var requestCount = 0;

    final client = MockClient((_) async {
      requestCount++;
      return http.Response('{}', 201);
    });

    final facade = AnalyticsFacade(
      ingestionService: HttpAnalyticsIngestionService(
        client: client,
      ),
    );

    await facade.initialize();
    await facade.trackScreenView(screen: 'Home');
    await facade.flush();

    final preferences = await SharedPreferences.getInstance();

    expect(requestCount, 0);
    expect(
      preferences.getStringList('analytics_event_queue'),
      hasLength(1),
    );
  });

  test('sends feature_used events with the expected contract', () async {
    SharedPreferences.setMockInitialValues({});

    final client = MockClient((request) async {
      expect(request.url.path, '/events/batch');

      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final events = body['events'] as List;
      final event = events.single as Map<String, dynamic>;

      expect(event['eventType'], 'feature_used');
      expect(event['feature'], 'friend_availability');
      expect(event['action'], 'view_availability');
      expect(event['screen'], 'FriendAvailability');
      expect(event['userId'], 'user-uuid');
      expect(event['eventId'], isNotEmpty);
      expect(event['sessionId'], isNotEmpty);
      expect(event['appVersion'], isNotEmpty);

      return http.Response('{}', 201);
    });

    final facade = AnalyticsFacade(
      ingestionService: HttpAnalyticsIngestionService(
        client: client,
      ),
    );

    await facade.initialize();
    facade.setUserId('user-uuid');

    await facade.trackFeatureUsed(
      feature: 'friend_availability',
      action: 'view_availability',
      screen: 'FriendAvailability',
    );

    await facade.flush();

    final preferences = await SharedPreferences.getInstance();

    expect(
      preferences.getStringList('analytics_event_queue'),
      isEmpty,
    );
  });
}
