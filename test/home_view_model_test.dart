import 'package:flutter_test/flutter_test.dart';
import 'package:llamalla/models/activity.dart';
import 'package:llamalla/models/profile_models.dart';
import 'package:llamalla/services/activity_service.dart';
import 'package:llamalla/services/location_service.dart';
import 'package:llamalla/services/profile_service.dart';
import 'package:llamalla/services/schedule_service.dart';
import 'package:llamalla/viewmodels/home_view_model.dart';

class _ProfileService extends ProfileService {
  @override
  Future<UserProfile> getCurrentUser() async => const UserProfile(
    id: '1',
    email: 'juan@test.com',
    name: 'Juan Pérez',
    bio: '',
  );
}

class _ScheduleService extends ScheduleService {
  @override
  Future<DayGaps> getGaps({
    required DateTime date,
    String timezone = 'America/Bogota',
  }) async {
    return DayGaps(
      date: date,
      timezone: timezone,
      free: [
        FreeInterval(
          start: DateTime(2026, 10, 3, 11, 30),
          end: DateTime(2026, 10, 3, 13),
        ),
      ],
    );
  }
}

class _ActivityService extends ActivityService {
  String? joinedId;
  String? joinedRecommendationId;
  int? joinedFreeMinutes;

  @override
  Future<RecommendationBatch> getRecommendations({
    required double lat,
    required double lon,
    double radiusKm = 5,
    String timezone = 'America/Bogota',
  }) async {
    return const RecommendationBatch(
      activities: [
        Activity(
          id: 'activity-1',
          category: 'Sports',
          name: 'Run',
          distance: '500 m',
          duration: '30 min',
          price: '',
          people: '0 registered',
          imageUrl: '',
        ),
      ],
      recommendationId: 'recommendation-1',
      freeMinutes: 45,
    );
  }

  @override
  Future<void> join(
    String activityId, {
    String? recommendationId,
    int? freeTimeMinutes,
  }) async {
    joinedId = activityId;
    joinedRecommendationId = recommendationId;
    joinedFreeMinutes = freeTimeMinutes;
  }
}

class _LocationService extends LocationService {
  @override
  Future<UserLocation> current() async => const UserLocation(4.6, -74.08);
}

class _FailingScheduleService extends ScheduleService {
  @override
  Future<DayGaps> getGaps({
    required DateTime date,
    String timezone = 'America/Bogota',
  }) async {
    throw const ScheduleException('Schedule unavailable');
  }
}

void main() {
  test('loads profile name and derives the next free interval', () async {
    final viewModel = HomeViewModel(
      profileService: _ProfileService(),
      scheduleService: _ScheduleService(),
      now: () => DateTime(2026, 10, 3, 9),
    );

    await viewModel.load();

    expect(viewModel.greetingName, 'Juan');
    expect(viewModel.freeMinutes, 90);
    expect(formatClockTime(viewModel.nextFreeInterval!.start), '11:30 AM');
    expect(viewModel.errorMessage, isNull);
    viewModel.dispose();
  });

  test('loads recommendations and preserves join analytics context', () async {
    final activityService = _ActivityService();
    final viewModel = HomeViewModel(
      profileService: _ProfileService(),
      scheduleService: _ScheduleService(),
      activityService: activityService,
      locationService: _LocationService(),
      now: () => DateTime(2026, 10, 3, 9),
    );

    await viewModel.load();
    expect(viewModel.recommendations, hasLength(1));
    expect(await viewModel.choose(viewModel.recommendations.single), isTrue);
    expect(activityService.joinedId, 'activity-1');
    expect(activityService.joinedRecommendationId, 'recommendation-1');
    expect(activityService.joinedFreeMinutes, 45);

    viewModel.dispose();
  });

  test('loads recommendations even when the schedule request fails', () async {
    final viewModel = HomeViewModel(
      profileService: _ProfileService(),
      scheduleService: _FailingScheduleService(),
      activityService: _ActivityService(),
      locationService: _LocationService(),
      now: () => DateTime(2026, 10, 3, 9),
    );

    await viewModel.load();
    expect(viewModel.errorMessage, 'Schedule unavailable');
    expect(viewModel.recommendations, hasLength(1));

    viewModel.dispose();
  });
}
