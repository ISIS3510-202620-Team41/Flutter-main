import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/calendar_models.dart';
import 'auth_service.dart';

class CalendarException implements Exception {
  const CalendarException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class CalendarService {
  CalendarService({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;

  Future<CalendarConnection> getConnection() async {
    final response = await _request('GET', '/calendar/google');
    return CalendarConnection.fromJson(_decode(response));
  }

  Future<CalendarSyncResult> connect() => _sync('/calendar/google/connect');

  Future<CalendarSyncResult> sync() => _sync('/calendar/google/sync');

  Future<void> disconnect() async {
    final response = await _authService.authenticatedRequest(
      method: 'DELETE',
      path: '/calendar/google',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _error(response, 'desconectar Google Calendar');
    }
  }

  Future<CalendarSyncResult> _sync(String path) async {
    final response = await _request('POST', path);
    return CalendarSyncResult.fromJson(_decode(response));
  }

  Future<http.Response> _request(String method, String path) {
    return _authService.authenticatedRequest(
      method: method,
      path: path,
      headers: const {'Content-Type': 'application/json'},
    );
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _error(response, 'sincronizar Google Calendar');
    }
    if (response.body.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const CalendarException('Respuesta inválida del calendario.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  CalendarException _error(http.Response response, String action) {
    var message = 'No fue posible $action.';
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['message'] is String) {
        message = body['message'] as String;
      }
    } on FormatException {
      // Use the standard message when the backend does not return JSON.
    }
    return CalendarException(message, statusCode: response.statusCode);
  }
}
