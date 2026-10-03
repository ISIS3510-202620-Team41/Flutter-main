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

  test(
    'Google token exchange posts the ID token and stores app tokens',
    () async {
      SharedPreferences.setMockInitialValues({});
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), 'http://test/api/auth/google');
        expect(jsonDecode(request.body), {'idToken': 'google-id-token'});
        return http.Response(
          jsonEncode({
            'accessToken': 'google-access-token',
            'refreshToken': 'google-refresh-token',
          }),
          200,
        );
      });

      final result = await AuthService(
        client: client,
        baseUrl: 'http://test/api',
      ).exchangeGoogleIdToken('google-id-token');

      final preferences = await SharedPreferences.getInstance();
      expect(result.accessToken, 'google-access-token');
      expect(preferences.getString('access_token'), 'google-access-token');
      expect(preferences.getString('refresh_token'), 'google-refresh-token');
    },
  );

  test('refresh rotates and persists the returned token pair', () async {
    SharedPreferences.setMockInitialValues({
      'refresh_token': 'old-refresh-token',
    });
    final client = MockClient((request) async {
      expect(request.url.toString(), 'http://test/api/auth/refresh');
      expect(jsonDecode(request.body), {'refreshToken': 'old-refresh-token'});
      return http.Response(
        jsonEncode({
          'accessToken': 'new-access-token',
          'refreshToken': 'new-refresh-token',
        }),
        200,
      );
    });

    await AuthService(client: client, baseUrl: 'http://test/api').refresh();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('access_token'), 'new-access-token');
    expect(preferences.getString('refresh_token'), 'new-refresh-token');
  });

  test(
    'restoreSession clears stale tokens when backend is unavailable',
    () async {
      SharedPreferences.setMockInitialValues({
        'access_token': 'access-token',
        'refresh_token': 'refresh-token',
      });
      final client = MockClient(
        (_) async => throw http.ClientException('Connection refused'),
      );

      final restored = await AuthService(
        client: client,
        baseUrl: 'http://test/api',
      ).restoreSession();

      final preferences = await SharedPreferences.getInstance();
      expect(restored, isFalse);
      expect(preferences.containsKey('access_token'), isFalse);
      expect(preferences.containsKey('refresh_token'), isFalse);
    },
  );

  test(
    'authenticated requests refresh once after an expired access token',
    () async {
      SharedPreferences.setMockInitialValues({
        'access_token': 'expired-access-token',
        'refresh_token': 'refresh-token',
      });
      var requestCount = 0;
      final client = MockClient((request) async {
        requestCount++;
        if (request.url.path.endsWith('/auth/refresh')) {
          return http.Response(
            jsonEncode({
              'accessToken': 'renewed-access-token',
              'refreshToken': 'renewed-refresh-token',
            }),
            200,
          );
        }
        expect(
          request.headers['authorization'],
          requestCount == 1
              ? 'Bearer expired-access-token'
              : 'Bearer renewed-access-token',
        );
        return http.Response('{}', requestCount == 1 ? 401 : 200);
      });

      final response = await AuthService(
        client: client,
        baseUrl: 'http://test/api',
      ).authenticatedRequest(method: 'GET', path: '/users/me');

      expect(response.statusCode, 200);
      expect(requestCount, 3);
    },
  );

  test('logout revokes the refresh token and clears local session', () async {
    SharedPreferences.setMockInitialValues({
      'access_token': 'access-token',
      'refresh_token': 'refresh-token',
    });
    final client = MockClient((request) async {
      expect(request.url.path, '/api/auth/logout');
      expect(jsonDecode(request.body), {'refreshToken': 'refresh-token'});
      return http.Response('', 204);
    });

    await AuthService(client: client, baseUrl: 'http://test/api').logout();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('access_token'), isFalse);
    expect(preferences.containsKey('refresh_token'), isFalse);
  });
}
