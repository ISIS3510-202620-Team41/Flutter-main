import 'package:flutter_test/flutter_test.dart';
import 'package:llamalla/models/activity.dart';
import 'package:llamalla/models/profile_models.dart';
import 'package:llamalla/services/activity_service.dart';
import 'package:llamalla/services/location_service.dart';
import 'package:llamalla/services/profile_service.dart';
import 'package:llamalla/services/schedule_service.dart';
import 'package:llamalla/viewmodels/home_view_model.dart';
import 'package:http/http.dart' as http;
import 'package:llamalla/analytics/http_analytics_ingestion_service.dart';
import 'package:http/testing.dart';
import 'package:llamalla/analytics/analytics_facade.dart';

class _RecordingAnalyticsFacade extends AnalyticsFacade {
  _RecordingAnalyticsFacade()
    : super(
        ingestionService: HttpAnalyticsIngestionService(
          client: MockClient(
            (_) async => http.Response('', 200),
          ),
        ),
      );

  final List<Map<String, String?>> featureEvents = [];

  @override
  Future<void> trackFeatureUsed({
    required String feature,
    String? action,
    String? screen,
  }) async {
    featureEvents.add({
      'feature': feature,
      'action': action,
      'screen': screen,
    });
  }
}

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
  bool failJoin = false;

  @override
  Future<RecommendationBatch> getRecommendations({
    required double lat,
    required double lon,
    double radiusKm = 5,
    String timezone = 'America/Bogota',
    bool calculateDistanceLocally = true,
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
  Future<void> join( String activityId, { String? recommendationId, int? freeTimeMinutes, }) async {
    if (failJoin) {
      throw Exception('Join failed');
    }
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
    final analytics = _RecordingAnalyticsFacade();
    final viewModel = HomeViewModel(
      profileService: _ProfileService(),
      scheduleService: _ScheduleService(),
      activityService: activityService,
      locationService: _LocationService(),
      now: () => DateTime(2026, 10, 3, 9),
      analyticsFacade: analytics,
    );

    await viewModel.load();
    expect(analytics.featureEvents, isEmpty);
    expect(viewModel.recommendations, hasLength(1));
    expect(await viewModel.choose(viewModel.recommendations.single), isTrue);
    expect(activityService.joinedId, 'activity-1');
    expect(activityService.joinedRecommendationId, 'recommendation-1');
    expect(activityService.joinedFreeMinutes, 45);
    expect(analytics.featureEvents, [
            {
              'feature': 'activity_recommendations',
              'action': 'select_recommendation',
              'screen': 'Home',
            },
            {
              'feature': 'activity_joining',
              'action': 'join_recommended_activity',
              'screen': 'Home',
            },
          ]);
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

  test('does not track activity joining when join fails', () async {
    final activityService = _ActivityService()
      ..failJoin = true;

    final analytics = _RecordingAnalyticsFacade();

    final viewModel = HomeViewModel(
      profileService: _ProfileService(),
      scheduleService: _ScheduleService(),
      activityService: activityService,
      locationService: _LocationService(),
      now: () => DateTime(2026, 10, 3, 9),
      analyticsFacade: analytics,
    );

    await viewModel.load();

    final result = await viewModel.choose(
      viewModel.recommendations.single,
    );

    expect(result, isFalse);

    expect(
      analytics.featureEvents.map((event) => event['feature']),
      ['activity_recommendations'],
    );

    viewModel.dispose();
  });

  test('does not track an activity without an ID', () async {
    final activityService = _ActivityService();
    final analytics = _RecordingAnalyticsFacade();

    final viewModel = HomeViewModel(
      profileService: _ProfileService(),
      scheduleService: _ScheduleService(),
      activityService: activityService,
      locationService: _LocationService(),
      now: () => DateTime(2026, 10, 3, 9),
      analyticsFacade: analytics,
    );

    await viewModel.load();

    const activityWithoutId = Activity(
      id: null,
      category: 'Sports',
      name: 'Run',
      distance: '500 m',
      duration: '30 min',
      price: '',
      people: '0 registered',
      imageUrl: '',
    );

    expect(
      await viewModel.choose(activityWithoutId),
      isFalse,
    );

    expect(analytics.featureEvents, isEmpty);
    expect(activityService.joinedId, isNull);

    viewModel.dispose();
  });
}
