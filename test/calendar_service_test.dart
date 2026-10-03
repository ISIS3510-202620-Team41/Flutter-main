import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:llamalla/services/auth_service.dart';
import 'package:llamalla/services/calendar_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'access_token': 'app-token'});
  });

  test('sync decodes normalized read-only Google events', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/calendar/google/sync');
      expect(request.headers['Authorization'], isNotEmpty);
      return http.Response(
        '{"connected":true,"email":"student@example.com",'
        '"lastSyncedAt":"2026-10-03T01:30:00Z","events":[{'
        '"id":"event-1","title":"Tutoría","startsAt":'
        '"2026-10-05T14:30:00-05:00","endsAt":'
        '"2026-10-05T15:30:00-05:00","location":"Google Meet",'
        '"allDay":false,"source":"google"}]}',
        200,
      );
    });
    final service = CalendarService(
      authService: AuthService(client: client, baseUrl: 'http://localhost:8080/api'),
    );

    final result = await service.sync();

    expect(result.connection.email, 'student@example.com');
    expect(result.events, hasLength(1));
    expect(result.events.single.title, 'Tutoría');
    expect(result.events.single.source, 'google');
  });

  test('disconnect surfaces backend errors', () async {
    final client = MockClient(
      (_) async => http.Response('{"message":"Calendar no disponible"}', 503),
    );
    final service = CalendarService(
      authService: AuthService(client: client, baseUrl: 'http://localhost:8080/api'),
    );

    expect(
      () => service.disconnect(),
      throwsA(
        isA<CalendarException>().having(
          (error) => error.message,
          'message',
          'Calendar no disponible',
        ),
      ),
    );
  });
}
