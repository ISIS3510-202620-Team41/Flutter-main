import 'package:flutter_test/flutter_test.dart';
import 'package:llamalla/cache/joined_activity_lru_cache.dart';
import 'package:llamalla/models/activity_record.dart';
import 'package:llamalla/models/joined_activity_record.dart';

JoinedActivityRecord _record(
  String userId,
  String activityId, {
  String? title,
}) {
  final now = DateTime.utc(2026, 11, 27);
  return JoinedActivityRecord(
    activity: ActivityRecord(
      id: activityId,
      title: title ?? 'Activity $activityId',
      category: 'CULTURA',
      startTime: '2026-12-01T10:00:00Z',
      endTime: '2026-12-01T12:00:00Z',
      locationName: 'Campus',
      latitude: 4.6,
      longitude: -74,
      participants: 1,
      cachedAt: now,
    ),
    userId: userId,
    enrollmentStatus: JoinedEnrollmentStatus.confirmed,
    syncStatus: JoinedSyncStatus.synced,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('inserts and reads an activity for its owner', () {
    final cache = JoinedActivityLruCache();
    final record = _record('user-a', 'activity-1');

    cache.insert(record);

    expect(cache.get(userId: 'user-a', activityId: 'activity-1'), same(record));
    expect(cache.length, 1);
  });

  test('reading an activity refreshes recency before eviction', () {
    final cache = JoinedActivityLruCache();
    for (
      var index = 0;
      index < JoinedActivityLruCache.defaultMaxEntries;
      index++
    ) {
      cache.insert(_record('user-a', 'activity-$index'));
    }

    final mostRecent = cache.get(userId: 'user-a', activityId: 'activity-0');
    cache.insert(_record('user-a', 'activity-20'));

    expect(mostRecent, isNotNull);
    expect(cache.get(userId: 'user-a', activityId: 'activity-0'), isNotNull);
    expect(cache.get(userId: 'user-a', activityId: 'activity-1'), isNull);
    expect(cache.length, JoinedActivityLruCache.defaultMaxEntries);
  });

  test('updates an existing entry without growing the cache', () {
    final cache = JoinedActivityLruCache();
    cache.insert(_record('user-a', 'activity-1'));
    final updated = _record('user-a', 'activity-1', title: 'Updated');

    cache.update(updated);

    expect(cache.length, 1);
    expect(
      cache.get(userId: 'user-a', activityId: 'activity-1')?.activity.title,
      'Updated',
    );
  });

  test('invalidates an entry and clears user or all entries', () {
    final cache = JoinedActivityLruCache()
      ..insert(_record('user-a', 'activity-1'))
      ..insert(_record('user-b', 'activity-1'));

    cache.invalidate(userId: 'user-a', activityId: 'activity-1');
    expect(cache.get(userId: 'user-a', activityId: 'activity-1'), isNull);
    expect(cache.get(userId: 'user-b', activityId: 'activity-1'), isNotNull);

    cache.clearUser('user-b');
    expect(cache.length, 0);

    cache.insert(_record('user-a', 'activity-2'));
    cache.clear();
    expect(cache.length, 0);
  });

  test('keeps records for different users isolated by composite identity', () {
    final cache = JoinedActivityLruCache()
      ..insert(_record('user-a', 'activity-1', title: 'A'))
      ..insert(_record('user-b', 'activity-1', title: 'B'));

    expect(
      cache.get(userId: 'user-a', activityId: 'activity-1')?.activity.title,
      'A',
    );
    expect(
      cache.get(userId: 'user-b', activityId: 'activity-1')?.activity.title,
      'B',
    );
  });

  test('does not expose an incomplete user snapshot after eviction', () {
    final cache = JoinedActivityLruCache();
    final records = List.generate(
      JoinedActivityLruCache.defaultMaxEntries + 1,
      (index) => _record('user-a', 'activity-$index'),
    );

    cache.replaceForUser('user-a', records);

    expect(cache.length, JoinedActivityLruCache.defaultMaxEntries);
    expect(cache.getForUser('user-a'), isNull);
  });
}
