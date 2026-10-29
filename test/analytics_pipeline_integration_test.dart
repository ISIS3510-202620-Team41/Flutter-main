import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:llamalla/analytics/analytics_facade.dart';
import 'package:llamalla/analytics/http_analytics_ingestion_service.dart';
import 'package:llamalla/analytics/shared_preferences_analytics_event_queue.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'retains a feature event after 503 and sends it after recovery',
    () async {
      final responses = <int>[503, 201];
      final requestBodies = <Map<String, dynamic>>[];
      var requestIndex = 0;

      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/events/batch');

        final body =
            jsonDecode(request.body) as Map<String, dynamic>;

        requestBodies.add(body);

        final statusCode = responses[requestIndex];
        requestIndex++;

        return http.Response('{}', statusCode);
      });

      addTearDown(client.close);

      final queue = SharedPreferencesAnalyticsEventQueue();

      final ingestionService = HttpAnalyticsIngestionService(
        client: client,
        baseUrl: 'https://analytics.example',
        ingestKey: '',
      );

      final facade = AnalyticsFacade(
        eventQueue: queue,
        ingestionService: ingestionService,
      );

      await facade.initialize();

      facade.setUserId('user-uuid');

      // setUserId inicia un flush no esperado por el llamador.
      // Damos oportunidad a ese primer flush, con la cola vacía,
      // de terminar antes de registrar el evento de esta prueba.
      await Future<void>.delayed(Duration.zero);

      await facade.trackFeatureUsed(
        feature: 'activity_recommendations',
        action: 'select_recommendation',
        screen: 'Home',
      );

      // Primer intento: el motor devuelve 503.
      await facade.flush();

      expect(requestIndex, 1);
      expect(
        await queue.readBatch(),
        hasLength(1),
      );

      final firstEvents =
          requestBodies[0]['events'] as List<dynamic>;

      final firstEvent =
          firstEvents.single as Map<String, dynamic>;

      expect(firstEvent['eventType'], 'feature_used');
      expect(
        firstEvent['feature'],
        'activity_recommendations',
      );
      expect(firstEvent['action'], 'select_recommendation');
      expect(firstEvent['screen'], 'Home');
      expect(firstEvent['userId'], 'user-uuid');
      expect(firstEvent['eventId'], isNotEmpty);
      expect(firstEvent['sessionId'], isNotEmpty);
      expect(firstEvent['timestamp'], isNotEmpty);
      expect(firstEvent['appVersion'], isNotEmpty);

      final originalEventId = firstEvent['eventId'];

      // Segundo intento: el motor vuelve a estar disponible.
      await facade.flush();

      expect(requestIndex, 2);
      expect(
        await queue.readBatch(),
        isEmpty,
      );

      final secondEvents =
          requestBodies[1]['events'] as List<dynamic>;

      final secondEvent =
          secondEvents.single as Map<String, dynamic>;

      // El mismo evento se reenvió, no se construyó uno nuevo.
      expect(secondEvent['eventId'], originalEventId);
      expect(secondEvent['userId'], 'user-uuid');
      expect(secondEvent['feature'], 'activity_recommendations');
    },
  );

  test(
    'removes a batch when ingestion classifies it as discarded',
    () async {
      final client = MockClient(
        (_) async => http.Response('{}', 422),
      );

      addTearDown(client.close);

      final queue = SharedPreferencesAnalyticsEventQueue();

      final ingestionService = HttpAnalyticsIngestionService(
        client: client,
        baseUrl: 'https://analytics.example',
        ingestKey: '',
      );

      final facade = AnalyticsFacade(
        eventQueue: queue,
        ingestionService: ingestionService,
      );

      await facade.initialize();

      facade.setUserId('user-uuid');

      await Future<void>.delayed(Duration.zero);

      await facade.trackScreenView(screen: 'Home');
      await facade.flush();

      expect(
        await queue.readBatch(),
        isEmpty,
      );
    },
  );
}