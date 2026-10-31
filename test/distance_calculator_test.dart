import 'package:flutter_test/flutter_test.dart';

import 'package:llamalla/models/activity_record.dart';
import 'package:llamalla/utils/distance_calculator.dart';

void main() {
  final activities = [
    ActivityRecord(
      id: 'far',
      title: 'Far activity',
      category: 'SPORTS',
      startTime: '2026-10-30T17:00:00Z',
      endTime: '2026-10-30T18:00:00Z',
      locationName: 'Far location',
      latitude: 0,
      longitude: 0.1,
      participants: 2,
      cachedAt: DateTime.utc(2026, 10, 30),
    ),
    ActivityRecord(
      id: 'near',
      title: 'Near activity',
      category: 'SPORTS',
      startTime: '2026-10-30T17:00:00Z',
      endTime: '2026-10-30T18:00:00Z',
      locationName: 'Near location',
      latitude: 0,
      longitude: 0.01,
      participants: 2,
      cachedAt: DateTime.utc(2026, 10, 30),
    ),
    ActivityRecord(
      id: 'middle',
      title: 'Middle activity',
      category: 'STUDY',
      startTime: '2026-10-30T17:00:00Z',
      endTime: '2026-10-30T18:00:00Z',
      locationName: 'Middle location',
      latitude: 0,
      longitude: 0.04,
      participants: 2,
      cachedAt: DateTime.utc(2026, 10, 30),
    ),
  ];

  test('calculates distances using batch processing', () async {
    final result = await DistanceCalculator.process(
      records: activities,
      userLat: 0,
      userLon: 0,
      radiusKm: 20,
      filterByRadius: false,
      sortByDistance: false,
    );

    expect(result, hasLength(3));

    expect(result[0].id, 'far');
    expect(result[0].distanceKm, isNotNull);
  });

  test('filters activities outside radius', () async {
    final result = await DistanceCalculator.process(
      records: activities,
      userLat: 0,
      userLon: 0,
      radiusKm: 5,
      filterByRadius: true,
      sortByDistance: false,
    );

    expect(result, hasLength(2));

    expect(
      result.map((activity) => activity.id),
      containsAll(['near', 'middle']),
    );

    expect(result.any((activity) => activity.id == 'far'), false);
  });

  test('sorts activities by distance', () async {
    final result = await DistanceCalculator.process(
      records: activities,
      userLat: 0,
      userLon: 0,
      radiusKm: 20,
      filterByRadius: true,
      sortByDistance: true,
    );

    expect(result, hasLength(3));

    expect(result[0].id, 'near');
    expect(result[1].id, 'middle');
    expect(result[2].id, 'far');

    expect(
      result[0].distanceKm!,
      lessThan(result[1].distanceKm!),
    );
  });

  test('returns an empty list when there are no activities', () async {
    final result = await DistanceCalculator.process(
      records: const [],
      userLat: 0,
      userLon: 0,
    );

    expect(result, isEmpty);
  });
}
