import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:llamalla/analytics/analytics_ingestion_service.dart';
import 'package:llamalla/analytics/http_analytics_ingestion_service.dart';

void main() {
  group('HttpAnalyticsIngestionService', () {
    test('sends a batch to the expected endpoint', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url,
          Uri.parse('https://analytics.example/events/batch'),
        );

        expect(
          request.headers.entries.any(
            (entry) =>
                entry.key.toLowerCase() == 'content-type' &&
                entry.value == 'application/json',
          ),
          isTrue,
        );

        expect(
          request.headers['X-API-Key'],
          'test-ingest-key',
        );

        final body =
            jsonDecode(request.body) as Map<String, dynamic>;
        final events = body['events'] as List<dynamic>;
        final event = events.single as Map<String, dynamic>;

        expect(event['eventId'], 'event-1');

        // El userId pasado al servicio debe prevalecer.
        expect(event['userId'], 'user-123');

        return http.Response('{}', 201);
      });

      final service = HttpAnalyticsIngestionService(
        client: client,
        baseUrl: 'https://analytics.example',
        ingestKey: 'test-ingest-key',
      );

      final result = await service.sendBatch(
        events: [
          {
            'eventId': 'event-1',
            'eventType': 'screen_view',
            'userId': 'previous-user',
          },
        ],
        userId: 'user-123',
      );

      expect(result, AnalyticsIngestionResult.accepted);
    });

    final scenarios =
        <MapEntry<int, AnalyticsIngestionResult>>[
      MapEntry(201, AnalyticsIngestionResult.accepted),
      MapEntry(401, AnalyticsIngestionResult.discarded),
      MapEntry(422, AnalyticsIngestionResult.discarded),
      MapEntry(400, AnalyticsIngestionResult.retained),
      MapEntry(503, AnalyticsIngestionResult.retained),
    ];

    for (final scenario in scenarios) {
      test(
        'maps HTTP ${scenario.key} to ${scenario.value.name}',
        () async {
          final client = MockClient(
            (_) async => http.Response('{}', scenario.key),
          );

          final service = HttpAnalyticsIngestionService(
            client: client,
            baseUrl: 'https://analytics.example',
            ingestKey: '',
          );

          final result = await service.sendBatch(
            events: [
              {'eventId': 'event-1'},
            ],
            userId: 'user-123',
          );

          expect(result, scenario.value);
        },
      );
    }

    test('retains events on a socket exception', () async {
      final client = MockClient(
        (_) async => throw const SocketException('offline'),
      );

      final service = HttpAnalyticsIngestionService(
        client: client,
        baseUrl: 'https://analytics.example',
        ingestKey: '',
      );

      final result = await service.sendBatch(
        events: [
          {'eventId': 'event-1'},
        ],
        userId: 'user-123',
      );

      expect(result, AnalyticsIngestionResult.retained);
    });

    test('retains events on timeout', () async {
      final pendingResponse = Completer<http.Response>();

      final client = MockClient(
        (_) => pendingResponse.future,
      );

      final service = HttpAnalyticsIngestionService(
        client: client,
        baseUrl: 'https://analytics.example',
        ingestKey: '',
        timeout: const Duration(milliseconds: 20),
      );

      final result = await service.sendBatch(
        events: [
          {'eventId': 'event-1'},
        ],
        userId: 'user-123',
      );

      expect(result, AnalyticsIngestionResult.retained);
    });
  });
}