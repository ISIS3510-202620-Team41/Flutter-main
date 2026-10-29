import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'analytics_ingestion_service.dart';

class HttpAnalyticsIngestionService implements AnalyticsIngestionService {
  HttpAnalyticsIngestionService({
    http.Client? client,
    String? baseUrl,
    String? ingestKey,
    this._timeout = const Duration(seconds: 2),
  })  : _client = client ?? http.Client(),
        _baseUrlOverride = baseUrl,
        _ingestKeyOverride = ingestKey;

  final http.Client _client;
  final String? _baseUrlOverride;
  final String? _ingestKeyOverride;
  final Duration _timeout;

  String get _baseUrl =>
      _baseUrlOverride ??
      _env('ANALYTICS_BASE_URL') ??
      'http://10.0.2.2:8000';

  String get _ingestKey =>
      _ingestKeyOverride ??
      _env('ANALYTICS_INGEST_KEY') ??
      '';

  @override
  Future<AnalyticsIngestionResult> sendBatch({
    required List<Map<String, dynamic>> events,
    required String userId,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/events/batch'),
            headers: {
              'Content-Type': 'application/json',
              if (_ingestKey.isNotEmpty) 'X-API-Key': _ingestKey,
            },
            body: jsonEncode({
              'events': events
                  .map(
                    (event) => {
                      ...event,
                      'userId': userId,
                    },
                  )
                  .toList(),
            }),
          )
          .timeout(_timeout);
          
      int statusCode = response.statusCode;

      if (statusCode == 201) {
        return AnalyticsIngestionResult.accepted;
      }

      if (statusCode == 401 ||
          statusCode == 422) {
        debugPrint(
          'Analytics batch discarded with HTTP '
          '$statusCode.',
        );

        return AnalyticsIngestionResult.discarded;
      }

      if (statusCode >= 500) {
        debugPrint(
          'Analytics engine unavailable; retaining event queue.',
        );

        return AnalyticsIngestionResult.retained;
      }

      debugPrint(
        'Analytics batch failed with unexpected HTTP '
        '$statusCode; retaining event queue.',
      );

      return AnalyticsIngestionResult.retained;
    } on SocketException catch (error) {
      debugPrint('Analytics network error: $error');

      return AnalyticsIngestionResult.retained;
    } on TimeoutException catch (error) {
      debugPrint('Analytics request timed out: $error');

      return AnalyticsIngestionResult.retained;
    }
  }

  static String? _env(String key) {
    if (!dotenv.isInitialized) return null;
    return dotenv.env[key];
  }
}