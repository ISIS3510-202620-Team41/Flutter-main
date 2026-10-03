import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/profile_models.dart';
import 'auth_service.dart';

class ScheduleException implements Exception {
  const ScheduleException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ScheduleService {
  ScheduleService({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;

  Future<GoogleConnectionStatus> getGoogleStatus() async {
    final response = await _request('GET', '/schedules/google/status');
    return GoogleConnectionStatus.fromJson(
      _decode(response, 'consultar la conexión de Google Calendar'),
    );
  }

  Future<GoogleSyncResult> syncGoogle({
    required String authCode,
    String timezone = 'America/Bogota',
  }) async {
    final response = await _request(
      'POST',
      '/schedules/sync/google?tz=${Uri.encodeQueryComponent(timezone)}',
      body: jsonEncode({'authCode': authCode}),
    );
    return GoogleSyncResult.fromJson(_decode(response, 'sincronizar Google Calendar'));
  }

  Future<GoogleSyncResult> refreshGoogle({
    String timezone = 'America/Bogota',
  }) async {
    final response = await _request(
      'POST',
      '/schedules/sync/google/refresh?tz=${Uri.encodeQueryComponent(timezone)}',
    );
    return GoogleSyncResult.fromJson(_decode(response, 'actualizar Google Calendar'));
  }

  Future<DayGaps> getGaps({
    required DateTime date,
    String timezone = 'America/Bogota',
  }) async {
    final dateValue =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final response = await _request(
      'GET',
      '/schedules/me/gaps?date=$dateValue&tz=${Uri.encodeQueryComponent(timezone)}',
    );
    return DayGaps.fromJson(_decode(response, 'cargar el horario'));
  }

  Future<http.Response> _request(
    String method,
    String path, {
    String? body,
  }) {
    return _authService.authenticatedRequest(
      method: method,
      path: path,
      headers: const {'Content-Type': 'application/json'},
      body: body,
    );
  }

  Map<String, dynamic> _decode(http.Response response, String action) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _error(response, action);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const ScheduleException('Respuesta inválida del horario.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  ScheduleException _error(http.Response response, String action) {
    var message = 'No fue posible $action.';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['message'] is String) {
        message = decoded['message'] as String;
      }
    } on FormatException {
      // Use the standard message when the backend does not return JSON.
    }
    return ScheduleException(message, statusCode: response.statusCode);
  }
}
