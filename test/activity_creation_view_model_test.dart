import 'package:flutter_test/flutter_test.dart';
import 'package:llamalla/models/activity.dart';
import 'package:llamalla/models/activity_draft.dart';
import 'package:llamalla/models/plan_creation_context.dart';
import 'package:llamalla/repositories/activity_repository.dart';
import 'package:llamalla/services/activity_service.dart';
import 'package:llamalla/services/friends_service.dart';
import 'package:llamalla/services/location_service.dart';
import 'package:llamalla/viewmodels/friends_view_model.dart';

class _FakeFriendsService extends FriendsService {
  _FakeFriendsService({
    this.friends = const [
      FriendStatus(
        initials: 'AL',
        name: 'Alex',
        status: 'Libre',
        email: 'alex@example.com',
      ),
      FriendStatus(
        initials: 'SA',
        name: 'Sam',
        status: 'Libre',
        email: 'sam@example.com',
      ),
      FriendStatus(
        initials: 'JO',
        name: 'Jordan',
        status: 'Libre',
        email: 'jordan@example.com',
      ),
    ],
  });

  final List<FriendStatus> friends;

  @override
  Future<List<FriendStatus>> loadAvailableFriends() async => friends;
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
        freeTimeMinutes: 45,
        now: () => DateTime.utc(2026, 11, 27, 10),
      );

      expect(viewModel.selectedFriends, isEmpty);
      await viewModel.loadFriends();
      viewModel
        ..toggleFriend(viewModel.availableFriends[0])
        ..toggleFriend(viewModel.availableFriends[1]);
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
      expect(draft.attemptId, isNot(draft.clientId));
      final context = draft.planCreationContext!;
      expect(context.preferences, ['DEPORTES']);
      expect(context.freeTimeMinutes, 45);
      expect(draft.endTime.difference(draft.startTime).inMinutes, 120);
      expect(context.locationName, 'Bistro');
      expect(context.latitude, 4.6);
      expect(context.longitude, -74);
      expect(context.availableFriendsCount, 3);
      expect(context.selectedAvailableFriendsCount, 2);
      expect(draft.friends, ['Alex', 'Sam']);
    },
  );

  test('does not substitute place duration when free time is unavailable',
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
    viewModel.toggleFriend(viewModel.availableFriends.first);
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
    expect(repository.createdDraft!.attemptId, isNull);
    expect(
      repository.createdDraft!.planCreationContext!.freeTimeMinutes,
      isNull,
    );
    expect(
      repository.createdDraft!.endTime
          .difference(repository.createdDraft!.startTime)
          .inMinutes,
      120,
    );
  });

  test('counts selected available friends using email identity', () async {
    final duplicateNames = _FakeFriendsService(
      friends: const [
        FriendStatus(
          initials: 'AL',
          name: 'Alex',
          status: 'Libre',
          email: 'alex.one@example.com',
        ),
        FriendStatus(
          initials: 'AL',
          name: 'Alex',
          status: 'Libre',
          email: 'alex.two@example.com',
        ),
      ],
    );
    final repository = _CapturingActivityRepository();
    final viewModel = ActivityCreationViewModel(
      repository: repository,
      friendsService: duplicateNames,
      activityService: ActivityService(),
      locationService: LocationService(),
      freeTimeMinutes: 45,
      now: () => DateTime.utc(2026, 11, 27, 10),
    );

    await viewModel.loadFriends();
    viewModel.toggleFriend(viewModel.availableFriends.first);
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
    expect(
      repository.createdDraft!.planCreationContext!.availableFriendsCount,
      2,
    );
    expect(
      repository
          .createdDraft!
          .planCreationContext!
          .selectedAvailableFriendsCount,
      1,
    );
    expect(repository.createdDraft!.friends, ['Alex']);
  });

  test('ActivityDraft storage preserves attempt ID and Type 5 context', () {
    const attemptId = '4a3cb35e-b63b-4e16-9f98-885d20a7a4fd';
    const context = PlanCreationContext(
      preferences: ['DEPORTES'],
      freeTimeMinutes: 45,
      locationName: 'Bistro',
      latitude: 4.6,
      longitude: -74,
      availableFriendsCount: 3,
      selectedAvailableFriendsCount: 1,
    );
    final draft = ActivityDraft(
      clientId: 'client-1',
      attemptId: attemptId,
      title: 'Deportes at Bistro',
      category: 'DEPORTES',
      startTime: DateTime.utc(2026, 11, 27, 10),
      endTime: DateTime.utc(2026, 11, 27, 12),
      locationName: 'Bistro',
      latitude: 4.6,
      longitude: -74,
      friends: ['alex@example.com'],
      planCreationContext: context,
    );

    final restored = ActivityDraft.fromStorageJson(draft.toStorageJson());

    expect(restored.attemptId, attemptId);
    expect(restored.clientId, isNot(attemptId));
    expect(restored.planCreationContext?.toMap(), context.toMap());
    expect(restored.toRequestJson()['attemptId'], attemptId);
  });
}
