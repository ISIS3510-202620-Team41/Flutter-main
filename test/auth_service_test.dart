import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:llamalla/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('login posts credentials and stores returned tokens', () async {
    SharedPreferences.setMockInitialValues({});
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.toString(), 'http://test/api/auth/login');
      expect(request.headers['content-type'], 'application/json');
      expect(jsonDecode(request.body), {
        'email': 'juan@test.com',
        'password': 'password123',
      });
      return http.Response(
        jsonEncode({
          'accessToken': 'access-token',
          'refreshToken': 'refresh-token',
        }),
        200,
      );
    });

    final result = await AuthService(
      client: client,
      baseUrl: 'http://test/api',
    ).login(email: 'juan@test.com', password: 'password123');

    final preferences = await SharedPreferences.getInstance();
    expect(result.accessToken, 'access-token');
    expect(preferences.getString('access_token'), 'access-token');
    expect(preferences.getString('refresh_token'), 'refresh-token');
  });

  test('login surfaces backend errors', () async {
    final client = MockClient(
      (_) async =>
          http.Response(jsonEncode({'message': 'Credenciales invalidas'}), 401),
    );

    expect(
      () => AuthService(
        client: client,
        baseUrl: 'http://test/api',
      ).login(email: 'juan@test.com', password: 'wrong'),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          'Credenciales invalidas',
        ),
      ),
    );
  });
}
