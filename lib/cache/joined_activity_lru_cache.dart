import 'dart:collection';

import '../models/joined_activity_record.dart';

typedef _JoinedActivityKey = ({String userId, String activityId});

class JoinedActivityLruCache {
  JoinedActivityLruCache({this.maxEntries = defaultMaxEntries}) {
    if (maxEntries < 1) {
      throw ArgumentError.value(maxEntries, 'maxEntries');
    }
  }

  static const defaultMaxEntries = 20;

  final int maxEntries;
  final LinkedHashMap<_JoinedActivityKey, JoinedActivityRecord> _entries =
      LinkedHashMap();
  final Set<String> _completeUsers = {};

  int get length => _entries.length;

  JoinedActivityRecord? get({
    required String userId,
    required String activityId,
  }) {
    final key = (userId: userId, activityId: activityId);
    final record = _entries.remove(key);
    if (record == null) return null;
    _entries[key] = record;
    return record;
  }

  List<JoinedActivityRecord>? getForUser(String userId) {
    if (!_completeUsers.contains(userId)) return null;

    final keys = _entries.keys
        .where((key) => key.userId == userId)
        .toList(growable: false);
    final records = <JoinedActivityRecord>[];
    for (final key in keys) {
      final record = get(userId: key.userId, activityId: key.activityId);
      if (record != null) records.add(record);
    }
    return List.unmodifiable(records);
  }

  void insert(JoinedActivityRecord record) {
    _put(record);
  }

  void update(JoinedActivityRecord record) {
    _put(record);
  }

  void replaceForUser(String userId, Iterable<JoinedActivityRecord> records) {
    clearUser(userId);
    final snapshot = records.toList(growable: false);
    for (final record in snapshot) {
      if (record.userId != userId) {
        throw ArgumentError('Cache entries must belong to $userId.');
      }
      _put(record);
    }
    if (snapshot.length <= maxEntries &&
        _entries.keys.where((key) => key.userId == userId).length ==
            snapshot.length) {
      _completeUsers.add(userId);
    }
  }

  void invalidate({required String userId, required String activityId}) {
    _entries.remove((userId: userId, activityId: activityId));
    _completeUsers.remove(userId);
  }

  void clearUser(String userId) {
    _entries.removeWhere((key, _) => key.userId == userId);
    _completeUsers.remove(userId);
  }

  void clear() {
    _entries.clear();
    _completeUsers.clear();
  }

  void _put(JoinedActivityRecord record) {
    final key = (userId: record.userId, activityId: record.activity.id);
    _entries.remove(key);
    _entries[key] = record;
    _completeUsers.remove(record.userId);

    if (_entries.length > maxEntries) {
      final evicted = _entries.keys.first;
      _entries.remove(evicted);
      _completeUsers.remove(evicted.userId);
    }
  }
}
