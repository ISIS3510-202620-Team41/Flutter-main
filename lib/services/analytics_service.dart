import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class AnalyticsService {
  AnalyticsService({http.Client? client})
    : _client = client ?? http.Client(),
      _uuid = const Uuid();

  static final instance = AnalyticsService();

  static const _queueKey = 'analytics_event_queue';
  static const _crashKey = 'analytics_pending_crashes';
  static const _baseUrl = String.fromEnvironment(
    'ANALYTICS_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
  static const _ingestKey = String.fromEnvironment('ANALYTICS_INGEST_KEY');

  final http.Client _client;
  final Uuid _uuid;
  SharedPreferences? _preferences;
  String? _userId;
  String? _currentScreen;
  String _sessionId = '';
  bool _isFlushing = false;

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
    _sessionId = _uuid.v4();
    final pendingCrashes = _preferences!.getStringList(_crashKey) ?? [];
    for (final encoded in pendingCrashes) {
      try {
        final crash = jsonDecode(encoded);
        if (crash is Map<String, dynamic>) {
          await track('crash', crash);
        }
      } on FormatException {
        debugPrint('Discarding malformed persisted crash event.');
      }
    }
    await _preferences!.remove(_crashKey);
  }

  void setUserId(String? userId) {
    _userId = userId;
    if (userId != null) unawaited(flush());
  }

  void setCurrentScreen(String? screen) {
    _currentScreen = screen;
  }

  Future<void> track(
    String eventType, [
    Map<String, dynamic> fields = const {},
  ]) async {
    final preferences = _preferences;
    if (preferences == null) return;
    final event = <String, dynamic>{
      'eventType': eventType,
      'eventId': _uuid.v4(),
      'sessionId': _sessionId,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      ...fields,
    };
    final appVersion = const String.fromEnvironment(
      'APP_VERSION',
      defaultValue: '1.0.0',
    );
    event['appVersion'] = appVersion;
    await _saveEvent(event);
  }

  Future<void> recordCrash({String? component, required Object error}) async {
    final preferences = _preferences;
    if (preferences == null) return;
    final crashes = preferences.getStringList(_crashKey) ?? [];
    crashes.add(
      jsonEncode({
        'screen': _currentScreen ?? 'Unknown',
        'component': ?component,
        'exceptionType': error.runtimeType.toString(),
      }),
    );
    await preferences.setStringList(_crashKey, crashes);
  }

  Future<void> flush() async {
    final preferences = _preferences;
    final userId = _userId;
    if (_isFlushing || preferences == null || userId == null) return;

    final events = _readEvents(preferences).take(200).toList();
    if (events.isEmpty) return;
    _isFlushing = true;
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
                  .map((event) => {...event, 'userId': userId})
                  .toList(),
            }),
          )
          .timeout(const Duration(seconds: 2));
      if (response.statusCode == 201 ||
          response.statusCode == 401 ||
          response.statusCode == 422) {
        final discardedIds = events
            .map((event) => event['eventId'])
            .whereType<String>()
            .toSet();
        final remaining = _readEvents(
          preferences,
        ).where((event) => !discardedIds.contains(event['eventId'])).toList();
        await _saveEvents(remaining);
        if (response.statusCode != 201) {
          debugPrint(
            'Analytics batch discarded with HTTP ${response.statusCode}.',
          );
        }
      } else if (response.statusCode >= 500) {
        debugPrint('Analytics engine unavailable; retaining event queue.');
      } else {
        debugPrint(
          'Analytics batch failed with unexpected HTTP '
          '${response.statusCode}; retaining event queue.',
        );
      }
    } on SocketException catch (error) {
      debugPrint('Analytics network error: $error');
    } on TimeoutException catch (error) {
      debugPrint('Analytics request timed out: $error');
    } finally {
      _isFlushing = false;
    }
  }

  List<Map<String, dynamic>> _readEvents(SharedPreferences preferences) {
    return (preferences.getStringList(_queueKey) ?? [])
        .map((encoded) {
          try {
            final decoded = jsonDecode(encoded);
            return decoded is Map<String, dynamic> ? decoded : null;
          } on FormatException {
            return null;
          }
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<void> _saveEvent(Map<String, dynamic> event) async {
    final preferences = _preferences!;
    final events = _readEvents(preferences)..add(event);
    await _saveEvents(events);
  }

  Future<void> _saveEvents(List<Map<String, dynamic>> events) {
    return _preferences!.setStringList(
      _queueKey,
      events.map(jsonEncode).toList(),
    );
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

class AnalyticsNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _track(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) _track(newRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  void _track(Route<dynamic> route) {
    final name = route.settings.name;
    final screen = name == null || name == '/'
        ? 'Home'
        : switch (name) {
            '/activity-detail' => 'ActivityDetail',
            '/activity/create' || '/activity-created' => 'ActivityDetail',
            '/login' => 'Login',
            '/register' => 'Register',
            _ => null,
          };
    if (screen != null) {
      AnalyticsService.instance.setCurrentScreen(screen);
      unawaited(
        AnalyticsService.instance.track('screen_view', {'screen': screen}),
      );
    }
  }
}
