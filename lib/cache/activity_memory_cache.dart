import 'dart:collection';

import '../models/activity_record.dart';

// In-memory LRU (Least Recently Used) cache of activities, keyed by id.
// Capacidad: 50 entradas..
// Eviction policy: access recency.
class ActivityMemoryCache {
  ActivityMemoryCache({this.maxEntries = defaultMaxEntries})
      : assert(maxEntries > 0, 'maxEntries must be positive');

  static const defaultMaxEntries = 50;

  final int maxEntries;

  // A LinkedHashMap conserva el orden de inserción
  // list: la PRIMERA clave es la menos recientemente utilizada. O(1).
  final LinkedHashMap<String, ActivityRecord> _entries = LinkedHashMap();

  int get length => _entries.length;

  ActivityRecord? get(String id) {
    final record = _entries.remove(id);
    if (record == null) return null;
    _entries[id] = record; // re-insert at the end = most recent
    return record;
  }

  /// Returns the record WITHOUT changing its recency (useful for checks).
  ActivityRecord? peek(String id) => _entries[id];

  /// Inserts or replaces a record and evicts the least recently used one
  /// if the cache goes over [maxEntries].
  void put(ActivityRecord record) {
    _entries.remove(record.id); // so a replaced entry also becomes the most recent
    _entries[record.id] = record;

    if (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first); // least recently used
    }
  }

  void putAll(Iterable<ActivityRecord> records) => records.forEach(put);

  /// Removes a record, e.g. after it was deleted from SQLite.
  void remove(String id) => _entries.remove(id);

  void clear() => _entries.clear();
}