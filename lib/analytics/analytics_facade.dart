import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'analytics_screen_catalog.dart';
import 'analytics_event_queue.dart';
import 'shared_preferences_analytics_event_queue.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';


class AnalyticsFacade {
  AnalyticsFacade({
    http.Client? client,
    AnalyticsEventQueue? eventQueue,
    }) : _client = client ?? http.Client(),
         _eventQueue = eventQueue ?? SharedPreferencesAnalyticsEventQueue(),
         _uuid = const Uuid();

  static final instance = AnalyticsFacade();

  static String get _baseUrl =>
      _env('ANALYTICS_BASE_URL') ?? 'http://10.0.2.2:8000';
  static String get _ingestKey => _env('ANALYTICS_INGEST_KEY') ?? '';

  final http.Client _client;
  final Uuid _uuid;
  final AnalyticsEventQueue _eventQueue;
  bool _isInitialized = false;

  String? _userId;
  String? _currentScreen;
  String _currentDashboardTab = AnalyticsScreenCatalog.home;
  String get currentDashboardTab => _currentDashboardTab;
  String _sessionId = '';
  bool _isFlushing = false;

  Future<void> initialize() async {
    await _eventQueue.initialize();

    _sessionId = _uuid.v4();
    _isInitialized = true;

    final pendingCrashes = await _eventQueue.readPendingCrashes();
    
    for (final crash in pendingCrashes) {
      await _trackEvent('crash',crash);
    }

    await _eventQueue.clearPendingCrashes();
  }

  void setUserId(String? userId) {
    _userId = userId;
    if (userId != null) unawaited(flush());
  }

  // Funciones te tracking relacionadas a las BQ trackeamos screen, features y loading times
  Future<void> trackScreenView({ required String screen,}) async {
    _currentScreen = screen;

    if (AnalyticsScreenCatalog.dashboardTabs.contains(screen)) {
      _currentDashboardTab = screen;
    }

    await _trackEvent('screen_view', {'screen': screen,});
  }

  Future<void> trackFeatureUsed({required String feature, String? action, String? screen,}) {
  return _trackEvent('feature_used', {
    'feature': feature,
    'action': ?action,
    'screen': ?screen,
    });
  }

  Future<void> trackAppLoadingTime({ required String loadType, required Duration duration,}) {
  return _trackEvent('app_loading_time', {
    'loadType': loadType,
    'durationMs': duration.inMilliseconds,
    });
  }

  Future<void> _trackEvent(String eventType, [Map<String, dynamic> fields = const {},]) async {
    if (!_isInitialized) return;

    // Se agregan campos comunes a todos los eventos mas los adicionales especificos
    final event = <String, dynamic>{
      'eventType': eventType,
      'eventId': _uuid.v4(),
      'sessionId': _sessionId,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      ...fields,
    };

    final appVersion = _env('APP_VERSION') ?? '1.0.0';
    event['appVersion'] = appVersion;

    await _eventQueue.enqueueEvent(event);
  }

  Future<void> recordCrash({String? component, required Object error}) async {
    if (!_isInitialized) return;

    await _eventQueue.enqueuePendingCrash({
      'screen': _currentScreen ?? 'Unknown',
      'component': ?component,
      'exceptionType': error.runtimeType.toString(),
    });
  }

  Future<void> flush() async {
    final userId = _userId;

    if (_isFlushing || !_isInitialized || userId == null){
      return;
    }

    _isFlushing = true;

    try {
      final events = await _eventQueue.readBatch(limit: 200);
      
      if (events.isEmpty) return;

      final response = await _client.post(
        Uri.parse('$_baseUrl/events/batch'),
        headers: {
          'Content-Type': 'application/json',
          if (_ingestKey.isNotEmpty) 'X-API-Key': _ingestKey,
        },
        body: jsonEncode({
          'events': events.map((event) => {...event, 'userId': userId}).toList(),
        }),
      ).timeout(const Duration(seconds: 2));

      int statusCode = response.statusCode;

      if (statusCode == 201 || statusCode == 401 || statusCode == 422) {
        final discardedIds = events.map((event) => event['eventId']).whereType<String>().toSet();

        await _eventQueue.removeEventsById(discardedIds);

      } if (statusCode !=201) {
        debugPrint('Analytics batch discarded with HTPP ''$statusCode.',);
      } else if (statusCode >= 500) {
        debugPrint('Analytics engine unavailable; retaining event queue.',);
      } else {
        debugPrint( 'Analytics batch failed with unexpected HTTP ''$statusCode; retaining event queue.',);
      }
    } on SocketException catch (error) {
      debugPrint('Analytics network error: $error');
    } on TimeoutException catch (error) {
      debugPrint('Analytics request timed out: $error');
    } finally {
      _isFlushing = false;
    }
  }

  String? decodeUserId(String accessToken) {
    final parts = accessToken.split('.');
    if (parts.length != 3) return null;
    try {
      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      final subject = payload is Map<String, dynamic>
          ? payload['sub'] ?? payload['userId'] ?? payload['id']
          : null;
      return subject is String && subject.isNotEmpty ? subject : null;
    } on FormatException {
      return null;
    } on JsonUnsupportedObjectError {
      return null;
    }
  }

  static String? _env(String key) {
    if (!dotenv.isInitialized) return null;
    return dotenv.env[key];
  }

  static void installErrorHandlers() {
    final previousFlutterError = FlutterError.onError;
    FlutterError.onError = (details) {
      previousFlutterError?.call(details);
      unawaited(
        instance.recordCrash(
          component: 'FlutterError',
          error: details.exception,
        ),
      );
    };

    final previousPlatformError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      final handled = previousPlatformError?.call(error, stack) ?? false;
      unawaited(instance.recordCrash(error: error));
      return handled;
    };
  }
}