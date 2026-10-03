import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_service.dart';

final authSession = AuthSession();

class AuthService {
  AuthService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl =
          baseUrl ?? (_env('API_BASE_URL') ?? 'http://10.0.2.2:8080/api');

  final http.Client _client;
  final String _baseUrl;

  Future<RegistrationResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );

    final body = _decodeBody(response.body);
    _throwForError(response.statusCode, body, 'crear la cuenta');
    final result = _tokensFrom(body);
    await _saveTokens(result);
    return result;
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final body = _decodeBody(response.body);
    _throwForError(response.statusCode, body, 'iniciar sesión');
    final result = _tokensFrom(body);
    await _saveTokens(result);
    return result;
  }

  Future<AuthResult> loginWithGoogle() async {
    await GoogleSignIn.instance.initialize(
      serverClientId: (_env('GOOGLE_SERVER_CLIENT_ID') ?? '').isEmpty
          ? null
          : _env('GOOGLE_SERVER_CLIENT_ID'),
    );
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException(
        message: 'Google no devolvió un token de identidad.',
      );
    }
    return exchangeGoogleIdToken(idToken);
  }

  Future<AuthResult> exchangeGoogleIdToken(String idToken) async {
    if (idToken.trim().isEmpty) {
      throw const AuthException(
        message: 'Google no devolvió un token de identidad.',
      );
    }
    final response = await _client.post(
      Uri.parse('$_baseUrl/auth/google'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );
    final body = _decodeBody(response.body);
    _throwForError(response.statusCode, body, 'iniciar sesión con Google');
    final result = _tokensFrom(body);
    await _saveTokens(result);
    return result;
  }

  Future<bool> restoreSession() async {
    final preferences = await SharedPreferences.getInstance();
    final refreshToken = preferences.getString('refresh_token');
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      await refresh().timeout(const Duration(seconds: 5));
      return true;
    } on AuthException {
      await clearSession();
      return false;
    } on http.ClientException {
      await clearSession();
      return false;
    } on TimeoutException {
      await clearSession();
      return false;
    }
  }

  Future<AuthResult> refresh() async {
    final preferences = await SharedPreferences.getInstance();
    final refreshToken = preferences.getString('refresh_token');
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const SessionExpiredException();
    }

    final response = await _client.post(
      Uri.parse('$_baseUrl/auth/refresh'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );
    final body = _decodeBody(response.body);
    _throwForError(response.statusCode, body, 'renovar la sesión');
    final result = _tokensFrom(body);
    await _saveTokens(result);
    return result;
  }

  Future<void> logout() async {
    final preferences = await SharedPreferences.getInstance();
    final refreshToken = preferences.getString('refresh_token');
    try {
      if (refreshToken != null && refreshToken.isNotEmpty) {
        final response = await _client.post(
          Uri.parse('$_baseUrl/auth/logout'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refreshToken}),
        );
        _throwForError(
          response.statusCode,
          _decodeBody(response.body),
          'cerrar sesión',
        );
      }
    } finally {
      await clearSession();
    }
  }

  Future<void> clearSession() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('access_token');
    await preferences.remove('refresh_token');
    AnalyticsService.instance.setUserId(null);
  }

  Future<http.Response> authenticatedRequest({
    required String method,
    required String path,
    Map<String, String>? headers,
    Object? body,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    var accessToken = preferences.getString('access_token');
    if (accessToken == null || accessToken.isEmpty) {
      throw const SessionExpiredException();
    }

    Future<http.Response> send() {
      return _send(
        method: method,
        path: path,
        accessToken: accessToken!,
        headers: headers,
        body: body,
      );
    }

    var response = await send();
    if (response.statusCode != 401) return response;

    late final AuthResult refreshed;
    try {
      refreshed = await refresh();
    } on AuthException {
      await clearSession();
      authSession.setUnauthenticated();
      throw const SessionExpiredException();
    }
    accessToken = refreshed.accessToken;
    response = await send();
    if (response.statusCode == 401) {
      await clearSession();
      authSession.setUnauthenticated();
      throw const SessionExpiredException();
    }
    return response;
  }

  Future<http.Response> authenticatedMultipart({
    required String path,
    required String field,
    required String filePath,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final accessToken = preferences.getString('access_token');
    if (accessToken == null || accessToken.isEmpty) {
      throw const SessionExpiredException();
    }

    Future<http.Response> send(String token) async {
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl$path'))
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath(field, filePath));
      return http.Response.fromStream(await _client.send(request));
    }

    var response = await send(accessToken);
    if (response.statusCode != 401) return response;

    late final AuthResult refreshed;
    try {
      refreshed = await refresh();
    } on AuthException {
      await clearSession();
      authSession.setUnauthenticated();
      throw const SessionExpiredException();
    }
    response = await send(refreshed.accessToken);
    if (response.statusCode == 401) {
      await clearSession();
      authSession.setUnauthenticated();
      throw const SessionExpiredException();
    }
    return response;
  }

  Future<http.Response> _send({
    required String method,
    required String path,
    required String accessToken,
    Map<String, String>? headers,
    Object? body,
  }) {
    final requestHeaders = <String, String>{
      'Authorization': 'Bearer $accessToken',
      ...?headers,
    };
    final uri = Uri.parse('$_baseUrl$path');
    switch (method.toUpperCase()) {
      case 'GET':
        return _client.get(uri, headers: requestHeaders);
      case 'POST':
        return _client.post(uri, headers: requestHeaders, body: body);
      case 'PATCH':
        return _client.patch(uri, headers: requestHeaders, body: body);
      case 'DELETE':
        return _client.delete(uri, headers: requestHeaders);
      default:
        throw ArgumentError.value(method, 'method', 'Unsupported HTTP method');
    }
  }

  Future<void> _saveTokens(AuthResult result) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('access_token', result.accessToken);
    await preferences.setString('refresh_token', result.refreshToken);
    AnalyticsService.instance.setUserId(
      AnalyticsService.instance.decodeUserId(result.accessToken),
    );
  }

  void _throwForError(
    int statusCode,
    Map<String, dynamic> body,
    String action,
  ) {
    if (statusCode >= 200 && statusCode < 300) return;
    throw AuthException(
      message: body['message'] as String? ?? 'No fue posible $action.',
      statusCode: statusCode,
    );
  }

  AuthResult _tokensFrom(Map<String, dynamic> body) {
    final accessToken = body['accessToken'];
    final refreshToken = body['refreshToken'];
    if (accessToken is! String || refreshToken is! String) {
      throw const AuthException(
        message: 'La respuesta del servidor no es válida.',
      );
    }
    return AuthResult(accessToken: accessToken, refreshToken: refreshToken);
  }

  static String? _env(String key) {
    if (!dotenv.isInitialized) return null;
    return dotenv.env[key];
  }

  Map<String, dynamic> _decodeBody(String value) {
    try {
      final decoded = jsonDecode(value);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on FormatException {
      return <String, dynamic>{};
    }
  }
}

class AuthResult {
  const AuthResult({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

typedef RegistrationResult = AuthResult;

class AuthException implements Exception {
  const AuthException({required this.message, this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class SessionExpiredException extends AuthException {
  const SessionExpiredException()
    : super(
        message: 'Tu sesión expiró. Inicia sesión nuevamente.',
        statusCode: 401,
      );
}

class AuthSession extends ChangeNotifier {
  bool? isAuthenticated;

  void setAuthenticated() {
    if (isAuthenticated == true) return;
    isAuthenticated = true;
    notifyListeners();
  }

  void setUnauthenticated() {
    if (isAuthenticated == false) return;
    isAuthenticated = false;
    notifyListeners();
  }
}
