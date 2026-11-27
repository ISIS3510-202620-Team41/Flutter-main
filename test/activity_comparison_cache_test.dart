import 'package:flutter_test/flutter_test.dart';
import 'package:llamalla/cache/activity_comparison_cache.dart';
import 'package:llamalla/models/activity_comparison_criteria.dart';
import 'package:llamalla/models/activity_comparison_result.dart';
import 'package:llamalla/services/storage_capacity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const contribution = ActivityComparisonContribution(
    weight: 10,
    normalizedScore: 82,
    score: 8.2,
    explanation: 'Comparable value.',
  );
  const result = ActivityComparisonResult(
    activityId: 'activity-1',
    score: 82,
    contributions: {
      ActivityComparisonCriterion.duration: contribution,
      ActivityComparisonCriterion.category: contribution,
      ActivityComparisonCriterion.price: contribution,
      ActivityComparisonCriterion.location: contribution,
      ActivityComparisonCriterion.distance: contribution,
      ActivityComparisonCriterion.capacity: contribution,
    },
  );
  final freshCapacity = StorageCapacityService(
    readAvailableBytes: () async => 1024 * 1024 * 1024,
    minimumFreeBytes: 0,
    safetyMarginBytes: 0,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists and reuses bounded results per user', () async {
    final cache = ActivityComparisonCache(
      capacityService: freshCapacity,
      maxEntries: 2,
    );

    await cache.put(
      userId: 'user-1',
      key: 'selection-a',
      results: const [result],
    );
    final cached = await ActivityComparisonCache(
      capacityService: freshCapacity,
      maxEntries: 2,
    ).get(userId: 'user-1', key: 'selection-a', allowStale: false);

    expect(cached?.results.single.activityId, 'activity-1');
    expect(cached?.isStale, isFalse);
    expect(
      await ActivityComparisonCache(
        capacityService: freshCapacity,
      ).get(userId: 'user-2', key: 'selection-a', allowStale: true),
      isNull,
    );
  });

  test(
    'returns stale entries only when the caller allows offline reuse',
    () async {
      var now = DateTime.utc(2026, 11, 26);
      ActivityComparisonCache createCache() => ActivityComparisonCache(
        capacityService: freshCapacity,
        now: () => now,
      );
      final cache = createCache();
      await cache.put(
        userId: 'user-1',
        key: 'selection-a',
        results: const [result],
      );

      now = now.add(const Duration(minutes: 31));
      expect(
        await createCache().get(
          userId: 'user-1',
          key: 'selection-a',
          allowStale: false,
        ),
        isNull,
      );
      final offline = await createCache().get(
        userId: 'user-1',
        key: 'selection-a',
        allowStale: true,
      );
      expect(offline?.isStale, isTrue);

      now = now.add(const Duration(days: 8));
      expect(
        await createCache().get(
          userId: 'user-1',
          key: 'selection-a',
          allowStale: true,
        ),
        isNull,
      );
    },
  );

  test(
    'keeps an in-memory result but skips persistence with insufficient space',
    () async {
      final noSpace = StorageCapacityService(
        readAvailableBytes: () async => 0,
        minimumFreeBytes: 0,
        safetyMarginBytes: 0,
      );
      final cache = ActivityComparisonCache(capacityService: noSpace);
      await cache.put(
        userId: 'user-1',
        key: 'selection-a',
        results: const [result],
      );

      expect(
        (await cache.get(
          userId: 'user-1',
          key: 'selection-a',
          allowStale: false,
        ))?.results.single.activityId,
        'activity-1',
      );
      expect(
        await ActivityComparisonCache(
          capacityService: freshCapacity,
        ).get(userId: 'user-1', key: 'selection-a', allowStale: true),
        isNull,
      );
    },
  );
}
