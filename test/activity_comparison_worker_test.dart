import 'package:flutter_test/flutter_test.dart';
import 'package:llamalla/models/activity_comparison_criteria.dart';
import 'package:llamalla/services/activity_comparison_worker.dart';

void main() {
  const criteria = ActivityComparisonCriteria();

  Map<String, Object?> activity({
    required String id,
    required String category,
    required String price,
    required String location,
    required int startHour,
    required int durationMinutes,
    required double longitude,
    required int participants,
    required int capacity,
  }) {
    final start = DateTime.utc(2026, 11, 26, startHour);
    final end = start.add(Duration(minutes: durationMinutes));
    return {
      'id': id,
      'category': category,
      'start_time': start.toIso8601String(),
      'end_time': end.toIso8601String(),
      'price': price,
      'location_name': location,
      'latitude': 4.6,
      'longitude': longitude,
      'participants': participants,
      'capacity': capacity,
    };
  }

  Map<String, Object?> payload(
    List<Map<String, Object?>> records, {
    Map<String, int>? weights,
    String? preferredLocation,
    List<String> preferredCategories = const [],
    double? referenceLatitude = 4.6,
    double? referenceLongitude = -74.0,
  }) => {
    'records': records,
    'weights':
        weights ??
        {
          for (final entry in criteria.weights.entries)
            entry.key.key: entry.value,
        },
    'preferredLocation': preferredLocation,
    'preferredCategories': preferredCategories,
    'referenceLatitude': referenceLatitude,
    'referenceLongitude': referenceLongitude,
  };

  test('scores two activities and returns criterion contributions', () {
    final result = compareActivitiesInWorker(
      payload(
        [
          activity(
            id: 'a',
            category: 'SPORTS',
            price: 'Gratis',
            location: 'North Hall',
            startHour: 10,
            durationMinutes: 45,
            longitude: -74.001,
            participants: 2,
            capacity: 12,
          ),
          activity(
            id: 'b',
            category: 'CULTURE',
            price: '\$20.000',
            location: 'Arts Building',
            startHour: 10,
            durationMinutes: 90,
            longitude: -74.02,
            participants: 8,
            capacity: 10,
          ),
        ],
        preferredLocation: 'North Hall',
        preferredCategories: ['SPORTS'],
      ),
    );

    expect(result, hasLength(2));
    expect(result.first['activityId'], 'a');
    final contributions = result.first['contributions'] as Map<String, Object?>;
    expect((contributions['location'] as Map)['normalizedScore'], 100);
    expect((contributions['category'] as Map)['normalizedScore'], 100);
    expect(result.first['score'], greaterThan(result.last['score'] as double));
    expect(
      result.first['score'],
      closeTo(
        (contributions.values as Iterable).cast<Map>().fold<double>(
          0,
          (sum, item) => sum + (item['score'] as num),
        ),
        0.001,
      ),
    );
  });

  test(
    'weights can change the ranking and zero weight contributes nothing',
    () {
      final records = [
        activity(
          id: 'cheap',
          category: 'SPORTS',
          price: 'Gratis',
          location: 'North Hall',
          startHour: 10,
          durationMinutes: 120,
          longitude: -74.02,
          participants: 8,
          capacity: 10,
        ),
        activity(
          id: 'short',
          category: 'SPORTS',
          price: '\$40.000',
          location: 'North Hall',
          startHour: 10,
          durationMinutes: 30,
          longitude: -74.001,
          participants: 1,
          capacity: 15,
        ),
      ];
      final durationWeights = {
        for (final entry
            in criteria
                .withWeight(ActivityComparisonCriterion.duration, 60)
                .withWeight(ActivityComparisonCriterion.price, 0)
                .weights
                .entries)
          entry.key.key: entry.value,
      };
      final priceWeights = {
        for (final entry
            in criteria
                .withWeight(ActivityComparisonCriterion.price, 60)
                .withWeight(ActivityComparisonCriterion.duration, 0)
                .weights
                .entries)
          entry.key.key: entry.value,
      };

      final durationRanking = compareActivitiesInWorker(
        payload(records, weights: durationWeights),
      );
      final priceRanking = compareActivitiesInWorker(
        payload(records, weights: priceWeights),
      );

      expect(durationRanking.first['activityId'], 'short');
      expect(priceRanking.first['activityId'], 'cheap');
      final priceResult = priceRanking.first['contributions'] as Map;
      expect((priceResult['duration'] as Map)['score'], 0);
      expect((priceResult['price'] as Map)['weight'], 60);
    },
  );

  test(
    'missing values and unconfigured location do not receive favorable scores',
    () {
      final record = activity(
        id: 'missing',
        category: 'SPORTS',
        price: 'Precio por confirmar',
        location: '',
        startHour: 10,
        durationMinutes: 45,
        longitude: -74.001,
        participants: 2,
        capacity: 12,
      )..remove('capacity');
      final result = compareActivitiesInWorker(
        payload([
          record,
          activity(
            id: 'known',
            category: 'SPORTS',
            price: 'Gratis',
            location: 'North Hall',
            startHour: 10,
            durationMinutes: 45,
            longitude: -74.001,
            participants: 2,
            capacity: 12,
          ),
        ]),
      ).firstWhere((item) => item['activityId'] == 'missing');
      final contributions = result['contributions'] as Map;

      expect((contributions['price'] as Map)['normalizedScore'], isNull);
      expect((contributions['price'] as Map)['score'], 0);
      expect((contributions['location'] as Map)['normalizedScore'], isNull);
      expect((contributions['location'] as Map)['score'], 0);
      expect((contributions['capacity'] as Map)['normalizedScore'], isNull);
      expect((contributions['capacity'] as Map)['score'], 0);
    },
  );

  test('returns 100 when all numeric values are equal', () {
    final records = [
      activity(
        id: 'a',
        category: 'SPORTS',
        price: 'Gratis',
        location: 'North Hall',
        startHour: 10,
        durationMinutes: 60,
        longitude: -74.0,
        participants: 2,
        capacity: 12,
      ),
      activity(
        id: 'b',
        category: 'CULTURE',
        price: 'Gratis',
        location: 'Arts Building',
        startHour: 10,
        durationMinutes: 60,
        longitude: -74.0,
        participants: 2,
        capacity: 12,
      ),
    ];

    final result = compareActivitiesInWorker(payload(records));

    for (final activityResult in result) {
      final contributions =
          activityResult['contributions'] as Map<String, Object?>;

      expect(
        (contributions['duration'] as Map)['normalizedScore'],
        100,
      );
      expect(
        (contributions['price'] as Map)['normalizedScore'],
        100,
      );
      expect(
        (contributions['distance'] as Map)['normalizedScore'],
        100,
      );
      expect(
        (contributions['capacity'] as Map)['normalizedScore'],
        100,
      );
    }
  });

  test('supports ten activities and breaks score ties by id', () {
    final records = List.generate(
      10,
      (index) => activity(
        id: 'activity-${9 - index}',
        category: 'SPORTS',
        price: 'Gratis',
        location: 'North Hall',
        startHour: 10,
        durationMinutes: 60,
        longitude: -74.0,
        participants: 2,
        capacity: 12,
      ),
    );

    final result = compareActivitiesInWorker(
      payload(records, preferredLocation: 'North Hall'),
    );

    expect(result, hasLength(10));
    expect(result.first['activityId'], 'activity-0');
    expect(result.last['activityId'], 'activity-9');
  });

  test('rejects invalid weights', () {
    final invalidWeights = {
      for (final entry in criteria.weights.entries) entry.key.key: entry.value,
      'duration': 0,
    };

    expect(
      () => compareActivitiesInWorker(
        payload([
          activity(
            id: 'a',
            category: 'SPORTS',
            price: 'Gratis',
            location: 'North Hall',
            startHour: 10,
            durationMinutes: 60,
            longitude: -74.0,
            participants: 2,
            capacity: 12,
          ),
        ], weights: invalidWeights),
      ),
      throwsFormatException,
    );
  });

  test('rebalance keeps the total at 100 and every weight at or below 60', () {
    final rebalanced = criteria.withWeight(
      ActivityComparisonCriterion.duration,
      0,
    );

    expect(rebalanced.totalWeight, 100);
    expect(rebalanced.weights.values.every((weight) => weight <= 60), isTrue);
    expect(
      criteria
          .withWeight(ActivityComparisonCriterion.duration, 100)
          .weights[ActivityComparisonCriterion.duration],
      60,
    );
  });
}
