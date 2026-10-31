import 'package:flutter_test/flutter_test.dart';
import 'package:llamalla/cache/activity_memory_cache.dart';
import 'package:llamalla/models/activity_record.dart';

ActivityRecord record(String id) => ActivityRecord(
  id: id,
  title: 'Activity $id',
  category: 'DEPORTES',
  startTime: '2026-10-30T17:00:00-05:00',
  endTime: '2026-10-30T19:00:00-05:00',
  locationName: 'Place',
  latitude: 4.6,
  longitude: -74.0,
  participants: 0,
  cachedAt: DateTime.utc(2026, 10, 29),
);

void main() {
  test('never keeps more than 50 entries and drops the oldest', () {
    final cache = ActivityMemoryCache();
    for (var i = 0; i < 60; i++) {
      cache.put(record('$i'));
    }
    expect(cache.length, 50);
    expect(cache.peek('0'), isNull);
    expect(cache.peek('9'), isNull);
    expect(cache.peek('10'), isNotNull);
    expect(cache.peek('59'), isNotNull);
  });

  test('reading an entry protects it from eviction', () {
    final cache = ActivityMemoryCache(maxEntries: 3);
    cache
      ..put(record('a'))
      ..put(record('b'))
      ..put(record('c'));

    cache.get('a'); // a becomes the most recently used
    cache.put(record('d')); // evicts b, not a

    expect(cache.peek('a'), isNotNull);
    expect(cache.peek('b'), isNull);
    expect(cache.peek('c'), isNotNull);
    expect(cache.peek('d'), isNotNull);
  });

  test('putting an existing id replaces it without growing', () {
    final cache = ActivityMemoryCache(maxEntries: 2);
    cache
      ..put(record('a'))
      ..put(record('b'))
      ..put(record('a'));

    expect(cache.length, 2);
    cache.put(record('c')); // b is now the oldest
    expect(cache.peek('b'), isNull);
    expect(cache.peek('a'), isNotNull);
  });

  test('remove deletes the entry', () {
    final cache = ActivityMemoryCache()..put(record('a'));
    cache.remove('a');
    expect(cache.peek('a'), isNull);
    expect(cache.length, 0);
  });
}