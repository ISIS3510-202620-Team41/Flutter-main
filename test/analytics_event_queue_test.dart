import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:llamalla/analytics/shared_preferences_analytics_event_queue.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists events and preserves FIFO order', () async {
    final queue = SharedPreferencesAnalyticsEventQueue();
    await queue.initialize();

    const firstEvent = {
      'eventId': 'event-1',
      'eventType': 'screen_view',
      'screen': 'Home',
    };

    const secondEvent = {
      'eventId': 'event-2',
      'eventType': 'feature_used',
      'feature': 'friend_availability',
    };

    await queue.enqueueEvent(firstEvent);
    await queue.enqueueEvent(secondEvent);

    expect(
      await queue.readBatch(),
      [firstEvent, secondEvent],
    );

    final preferences = await SharedPreferences.getInstance();

    expect(
      preferences.getStringList('analytics_event_queue'),
      [
        jsonEncode(firstEvent),
        jsonEncode(secondEvent),
      ],
    );
  });

  test('readBatch respects the requested limit', () async {
    final queue = SharedPreferencesAnalyticsEventQueue();
    await queue.initialize();

    for (var i = 1; i <= 3; i++) {
      await queue.enqueueEvent({
        'eventId': 'event-$i',
      });
    }

    expect(
      await queue.readBatch(limit: 2),
      [
        {'eventId': 'event-1'},
        {'eventId': 'event-2'},
      ],
    );

    expect(
      await queue.readBatch(limit: 0),
      isEmpty,
    );

    expect(
      await queue.readBatch(),
      hasLength(3),
    );
  });

  test('removes only the specified event IDs', () async {
    final queue = SharedPreferencesAnalyticsEventQueue();
    await queue.initialize();

    await queue.enqueueEvent({'eventId': 'event-1'});
    await queue.enqueueEvent({'eventId': 'event-2'});
    await queue.enqueueEvent({'eventId': 'event-3'});

    await queue.removeEventsById({'event-2'});

    expect(
      await queue.readBatch(),
      [
        {'eventId': 'event-1'},
        {'eventId': 'event-3'},
      ],
    );
  });

  test('persists and clears pending crashes', () async {
    final queue = SharedPreferencesAnalyticsEventQueue();
    await queue.initialize();

    const crash = {
      'screen': 'Home',
      'component': 'FlutterError',
      'exceptionType': 'StateError',
    };

    await queue.enqueuePendingCrash(crash);

    expect(
      await queue.readPendingCrashes(),
      [crash],
    );

    final preferences = await SharedPreferences.getInstance();

    expect(
      preferences.getStringList('analytics_pending_crashes'),
      [jsonEncode(crash)],
    );

    await queue.clearPendingCrashes();

    expect(
      preferences.getStringList('analytics_pending_crashes'),
      isNull,
    );
  });

  test('ignores malformed persisted events', () async {
    SharedPreferences.setMockInitialValues({
      'analytics_event_queue': [
        jsonEncode({'eventId': 'valid-event'}),
        '{not-valid-json',
        jsonEncode(['not', 'an', 'event-map']),
      ],
    });

    final queue = SharedPreferencesAnalyticsEventQueue();
    await queue.initialize();

    expect(
      await queue.readBatch(),
      [
        {'eventId': 'valid-event'},
      ],
    );
  });

  test('ignores malformed pending crashes', () async {
    SharedPreferences.setMockInitialValues({
      'analytics_pending_crashes': [
        jsonEncode({'screen': 'Home'}),
        '{not-valid-json',
        jsonEncode(['not', 'a', 'crash-map']),
      ],
    });

    final queue = SharedPreferencesAnalyticsEventQueue();
    await queue.initialize();

    expect(
      await queue.readPendingCrashes(),
      [
        {'screen': 'Home'},
      ],
    );

    await queue.clearPendingCrashes();

    final preferences = await SharedPreferences.getInstance();

    expect(
      preferences.getStringList('analytics_pending_crashes'),
      isNull,
    );
  });
}