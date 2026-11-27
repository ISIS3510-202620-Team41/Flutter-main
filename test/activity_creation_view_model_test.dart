import 'package:flutter_test/flutter_test.dart';
import 'package:llamalla/models/activity.dart';
import 'package:llamalla/models/activity_draft.dart';
import 'package:llamalla/repositories/activity_repository.dart';
import 'package:llamalla/services/activity_service.dart';
import 'package:llamalla/services/friends_service.dart';
import 'package:llamalla/services/location_service.dart';
import 'package:llamalla/viewmodels/friends_view_model.dart';

class _FakeFriendsService extends FriendsService {
  @override
  Future<List<FriendStatus>> loadAvailableFriends() async => const [
    FriendStatus(initials: 'AL', name: 'Alex', status: 'Libre'),
    FriendStatus(initials: 'SA', name: 'Sam', status: 'Libre'),
    FriendStatus(initials: 'JO', name: 'Jordan', status: 'Libre'),
  ];
}

class _CapturingActivityRepository extends ActivityRepository {
  ActivityDraft? createdDraft;

  @override
  Future<CreateResult> create(ActivityDraft draft, {String? source}) async {
    createdDraft = draft;
    return CreateResult(
      Activity(
        id: 'activity-1',
        category: draft.category,
        name: draft.title,
        distance: '',
        duration: '',
        price: '',
        people: '',
        imageUrl: '',
      ),
    );
  }
}

void main() {
  test(
    'captures the BQ14 context and UUID attempt ID from selected inputs',
    () async {
      final repository = _CapturingActivityRepository();
      final viewModel = ActivityCreationViewModel(
        repository: repository,
        friendsService: _FakeFriendsService(),
        activityService: ActivityService(),
        locationService: LocationService(),
        now: () => DateTime.utc(2026, 11, 27, 10),
      );

      await viewModel.loadFriends();
      viewModel.selectedFriends
        ..clear()
        ..addAll(['Alex', 'Sam']);
      viewModel.selectCategory(categoryOptions[0]);
      viewModel.selectPlace(
        const PlaceOption(
          name: 'Bistro',
          distance: '1 km',
          durationMinutes: 120,
          price: '\$30K',
          latitude: 4.6,
          longitude: -74,
          capacity: 10,
          description: 'Restaurante',
        ),
      );

      expect(await viewModel.submit(), isTrue);

      final draft = repository.createdDraft!;
      expect(draft.attemptId, matches(RegExp(r'^[0-9a-fA-F-]{36}$')));
      final context = draft.planCreationContext!;
      expect(context.preferences, ['DEPORTES']);
      expect(context.freeTimeMinutes, 120);
      expect(context.locationName, 'Bistro');
      expect(context.latitude, 4.6);
      expect(context.longitude, -74);
      expect(context.availableFriendsCount, 3);
      expect(context.selectedAvailableFriendsCount, 2);
    },
  );
}
