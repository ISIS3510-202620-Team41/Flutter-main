import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:llamalla/services/auth_service.dart';
import 'package:llamalla/services/schedule_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'access_token': 'access-token',
      'refresh_token': 'refresh-token',
    });
  });

  test(
    'reads Google connection status without refreshing the calendar',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          'http://test/api/schedules/google/status',
        );
        expect(request.headers['authorization'], 'Bearer access-token');
        return http.Response(jsonEncode({'connected': true}), 200);
      });

      final status = await ScheduleService(
        authService: AuthService(client: client, baseUrl: 'http://test/api'),
      ).getGoogleStatus();

      expect(status.connected, isTrue);
    },
  );

  test('gets gaps using backend time blocks', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(
        request.url.toString(),
        'http://test/api/schedules/me/gaps?date=2026-10-02&tz=America%2FBogota',
      );
      return http.Response(
        jsonEncode({
          'date': '2026-10-02',
          'timezone': 'America/Bogota',
          'free': [
            {
              'start': '2026-10-02T08:00:00-05:00',
              'end': '2026-10-02T10:00:00-05:00',
            },
          ],
        }),
        200,
      );
    });

    final gaps = await ScheduleService(
      authService: AuthService(client: client, baseUrl: 'http://test/api'),
    ).getGaps(date: DateTime(2026, 10, 2));

    expect(gaps.free, hasLength(1));
    expect(gaps.free.single.start.toUtc(), DateTime.utc(2026, 10, 2, 13));
    expect(gaps.free.single.end.toUtc(), DateTime.utc(2026, 10, 2, 15));
  });
}
