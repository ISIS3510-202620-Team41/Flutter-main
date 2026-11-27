import 'package:flutter_test/flutter_test.dart';
import 'package:llamalla/cache/activity_comparison_cache.dart';
import 'package:llamalla/models/activity_comparison_criteria.dart';
import 'package:llamalla/models/activity_record.dart';
import 'package:llamalla/services/activity_comparison_service.dart';
import 'package:llamalla/services/location_service.dart';
import 'package:llamalla/services/storage_capacity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DateTime now;
  late StorageCapacityService capacityService;

  ActivityRecord activity({
    required String id,
    required int durationMinutes,
    required double longitude,
    String price = 'Gratis',
    String location = 'North Hall',
  }) {
    final start = DateTime.utc(2026, 11, 30, 17);
    final end = start.add(Duration(minutes: durationMinutes));
    return ActivityRecord(
      id: id,
      title: id,
      description: null,
      category: 'SPORTS',
      startTime: start.toIso8601String(),
      endTime: end.toIso8601String(),
      locationName: location,
      latitude: 4.6,
      longitude: longitude,
      distanceKm: null,
      participants: 2,
      capacity: 12,
      price: price,
      aboutLocation: null,
      imageUrl: null,
      cachedAt: now,
    );
  }

  ActivityComparisonService createService() => ActivityComparisonService(
    comparisonCache: ActivityComparisonCache(
      capacityService: capacityService,
      now: () => now,
    ),
    now: () => now,
  );

  setUp(() {
    now = DateTime.utc(2026, 11, 26);
    SharedPreferences.setMockInitialValues({});
    capacityService = StorageCapacityService(
      readAvailableBytes: () async => 1024 * 1024 * 1024,
      minimumFreeBytes: 0,
      safetyMarginBytes: 0,
    );
  });

  test(
    'runs scoring in compute and reuses an order-independent cached result',
    () async {
      final records = [
        activity(id: 'a', durationMinutes: 45, longitude: -74.001),
        activity(
          id: 'b',
          durationMinutes: 90,
          longitude: -74.02,
          price: '\$20.000',
          location: 'Arts Building',
        ),
      ];
      final service = createService();
      const criteria = ActivityComparisonCriteria();

      final calculated = await service.compare(
        activities: records,
        criteria: criteria,
        preferredCategories: const {'SPORTS'},
        userId: 'user-1',
        referenceLocation: const UserLocation(4.6, -74.0),
        isOffline: false,
      );
      final cached = await createService().compare(
        activities: records.reversed.toList(),
        criteria: criteria,
        preferredCategories: const {'SPORTS'},
        userId: 'user-1',
        referenceLocation: const UserLocation(4.6, -74.0),
        isOffline: false,
      );

      expect(calculated.fromCache, isFalse);
      expect(cached.fromCache, isTrue);
      expect(cached.results.map((result) => result.activityId), ['a', 'b']);
    },
  );

  test('changes to weights invalidate the cached result', () async {
    final records = [
      activity(id: 'a', durationMinutes: 45, longitude: -74.001),
      activity(id: 'b', durationMinutes: 90, longitude: -74.02),
    ];
    final service = createService();
    const defaultCriteria = ActivityComparisonCriteria();

    await service.compare(
      activities: records,
      criteria: defaultCriteria,
      preferredCategories: const {},
      userId: 'user-1',
      referenceLocation: null,
      isOffline: false,
    );
    final changed = await createService().compare(
      activities: records,
      criteria: defaultCriteria.withWeight(
        ActivityComparisonCriterion.duration,
        60,
      ),
      preferredCategories: const {},
      userId: 'user-1',
      referenceLocation: null,
      isOffline: false,
    );

    expect(changed.fromCache, isFalse);
  });

  test(
    'allows stale cached results only offline and marks them stale',
    () async {
      final records = [
        activity(id: 'a', durationMinutes: 45, longitude: -74.001),
        activity(id: 'b', durationMinutes: 90, longitude: -74.02),
      ];
      final service = createService();

      await service.compare(
        activities: records,
        criteria: const ActivityComparisonCriteria(),
        preferredCategories: const {},
        userId: 'user-1',
        referenceLocation: null,
        isOffline: false,
      );
      now = now.add(const Duration(minutes: 31));
      final offline = await createService().compare(
        activities: records,
        criteria: const ActivityComparisonCriteria(),
        preferredCategories: const {},
        userId: 'user-1',
        referenceLocation: null,
        isOffline: true,
      );

      expect(offline.fromCache, isTrue);
      expect(offline.isStale, isTrue);
    },
  );
}
