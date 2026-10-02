import 'dart:convert';

import 'package:http/http.dart' as http;

class AuthService {
  AuthService({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'http://10.0.2.2:8080/api',
            );

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
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
      }),
    );

    final body = _decodeBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        message: body['message'] as String? ?? 'No fue posible crear la cuenta.',
        statusCode: response.statusCode,
      );
    }

    final accessToken = body['accessToken'];
    final refreshToken = body['refreshToken'];
    if (accessToken is! String || refreshToken is! String) {
      throw const AuthException(
        message: 'La respuesta del servidor no es válida.',
      );
    }

    return RegistrationResult(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
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

class RegistrationResult {
  const RegistrationResult({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;
}

class AuthException implements Exception {
  const AuthException({
    required this.message,
    this.statusCode,
  });

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
