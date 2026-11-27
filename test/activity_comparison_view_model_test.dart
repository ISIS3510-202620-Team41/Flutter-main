import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:llamalla/models/activity_comparison_criteria.dart';
import 'package:llamalla/models/activity_comparison_result.dart';
import 'package:llamalla/models/activity_record.dart';
import 'package:llamalla/services/activity_comparison_service.dart';
import 'package:llamalla/services/location_service.dart';
import 'package:llamalla/viewmodels/activity_comparison_view_model.dart';

class _ControlledComparisonService extends ActivityComparisonService {
  _ControlledComparisonService(this.activities);

  final List<ActivityRecord> activities;
  final calls = <Completer<ActivityComparisonCalculation>>[];

  @override
  Future<String> get userId async => 'user-1';

  @override
  Future<Set<String>> loadPreferredCategories(String userId) async => {};

  @override
  Future<ActivityComparisonActivityData> loadAvailableActivities() async =>
      ActivityComparisonActivityData(
        activities: activities,
        referenceLocation: null,
        locationIssue: null,
        isOffline: true,
      );

  @override
  Future<ActivityComparisonActivityData> refreshAvailableActivities(
    ActivityComparisonActivityData previous,
  ) async => previous;

  @override
  Future<ActivityComparisonCalculation> compare({
    required List<ActivityRecord> activities,
    required ActivityComparisonCriteria criteria,
    required Set<String> preferredCategories,
    required String userId,
    required UserLocation? referenceLocation,
    required bool isOffline,
  }) {
    final completer = Completer<ActivityComparisonCalculation>();
    calls.add(completer);
    return completer.future;
  }
}

ActivityRecord _activity(String id) => ActivityRecord(
  id: id,
  title: id,
  description: null,
  category: 'SPORTS',
  startTime: '2026-11-30T17:00:00Z',
  endTime: '2026-11-30T18:00:00Z',
  locationName: 'North Hall',
  latitude: 4.6,
  longitude: -74.0,
  distanceKm: null,
  participants: 2,
  capacity: 12,
  price: 'Gratis',
  aboutLocation: null,
  imageUrl: null,
  cachedAt: DateTime.utc(2026, 11, 26),
);

ActivityComparisonCalculation _calculation(String id) =>
    ActivityComparisonCalculation(
      results: [
        ActivityComparisonResult(
          activityId: id,
          score: 90,
          contributions: const {},
        ),
      ],
      calculatedAt: DateTime.utc(2026, 11, 26),
      fromCache: false,
      isStale: false,
    );

void main() {
  test('does not publish a result from an older calculation request', () async {
    final service = _ControlledComparisonService([
      _activity('a'),
      _activity('b'),
    ]);
    final viewModel = ActivityComparisonViewModel(comparisonService: service);
    addTearDown(viewModel.dispose);

    await viewModel.load();
    final firstRequest = viewModel.setSelectedActivityIds(['a', 'b']);
    viewModel.updateWeight(ActivityComparisonCriterion.duration, 40);
    final secondRequest = viewModel.commitWeights();

    expect(service.calls, hasLength(2));
    service.calls[1].complete(_calculation('new-result'));
    await secondRequest;
    service.calls[0].complete(_calculation('old-result'));
    await firstRequest;

    expect(viewModel.results.map((result) => result.activityId), [
      'new-result',
    ]);
  });

  test('enforces the maximum selection size before calculating', () async {
    final activities = List.generate(
      11,
      (index) => _activity('activity-$index'),
    );
    final service = _ControlledComparisonService(activities);
    final viewModel = ActivityComparisonViewModel(comparisonService: service);
    addTearDown(viewModel.dispose);

    await viewModel.load();

    await expectLater(
      viewModel.setSelectedActivityIds(
        activities.map((activity) => activity.id),
      ),
      throwsArgumentError,
    );
    expect(service.calls, isEmpty);
  });

  test('does not calculate with fewer than two selected activities', () async {
    final service = _ControlledComparisonService([
      _activity('a'),
      _activity('b'),
    ]);
    final viewModel = ActivityComparisonViewModel(comparisonService: service);
    addTearDown(viewModel.dispose);

    await viewModel.load();
    await viewModel.setSelectedActivityIds(['a']);

    expect(viewModel.results, isEmpty);
    expect(service.calls, isEmpty);
  });
}
