import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_event_queue.dart';

class SharedPreferencesAnalyticsEventQueue
    implements AnalyticsEventQueue {
  static const _queueKey = 'analytics_event_queue';
  static const _crashKey = 'analytics_pending_crashes';

  SharedPreferences? _preferences;

  SharedPreferences get _store {
    final preferences = _preferences;

    if (preferences == null) {
      throw StateError(
        'AnalyticsEventQueue has not been initialized.',
      );
    }

    return preferences;
  }

  @override
  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
  }

  @override
  Future<void> enqueueEvent(Map<String, dynamic> event,) async {
    final preferences = _store;

    final events = _readEvents(preferences)
      ..add(Map<String, dynamic>.from(event));

    await _saveEvents(preferences, events);
  }

  @override
  Future<List<Map<String, dynamic>>> readBatch({int limit = 200,}) async {
    if (limit <= 0) {
      return [];
    }

    final events = _readEvents(_store);

    return events.take(limit).toList();
  }

  @override
  Future<void> removeEventsById(Set<String> eventIds,) async {
    final preferences = _store;

    // Se vuelve a leer la cola para conservar los eventos
    // que hayan llegado mientras estaba en curso una petición HTTP.
    final remainingEvents = _readEvents(preferences)
        .where(
          (event) => !eventIds.contains(event['eventId']),
        )
        .toList();

    await _saveEvents(preferences, remainingEvents);
  }

  @override
  Future<void> enqueuePendingCrash(Map<String, dynamic> crash,) async {
    final preferences = _store;

    final crashes =
        preferences.getStringList(_crashKey) ?? <String>[];

    crashes.add(jsonEncode(crash));

    await preferences.setStringList(_crashKey, crashes);
  }

  @override
  Future<List<Map<String, dynamic>>> readPendingCrashes() async {
    final encodedCrashes =
        _store.getStringList(_crashKey) ?? <String>[];

    final crashes = <Map<String, dynamic>>[];

    for (final encoded in encodedCrashes) {
      try {
        final decoded = jsonDecode(encoded);

        if (decoded is Map<String, dynamic>) {
          crashes.add(decoded);
        }
      } on FormatException {
        debugPrint('Discarding malformed persisted crash event.');
      }
    }

    return crashes;
  }

  @override
  Future<void> clearPendingCrashes() async {
    await _store.remove(_crashKey);
  }

  List<Map<String, dynamic>> _readEvents( SharedPreferences preferences,) {
    return (preferences.getStringList(_queueKey) ?? <String>[])
        .map((encoded) {
          try {
            final decoded = jsonDecode(encoded);

            return decoded is Map<String, dynamic>
                ? decoded
                : null;
          } on FormatException {
            return null;
          }
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<void> _saveEvents(SharedPreferences preferences, List<Map<String, dynamic>> events,) {
    return preferences.setStringList(
      _queueKey,
      events.map(jsonEncode).toList(),
    );
  }
}