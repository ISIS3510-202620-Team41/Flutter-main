import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/activity.dart';
import '../models/plan_creation_context.dart';
import '../services/friends_service.dart';
import '../services/location_service.dart';
import '../models/activity_draft.dart';
import '../repositories/activity_repository.dart';
import '../services/activity_service.dart';

class FriendsViewModel extends ChangeNotifier {
  FriendsViewModel({FriendsService? friendsService})
    : _friendsService = friendsService ?? FriendsService();

  final FriendsService _friendsService;

  List<FriendStatus> _friends = const [];
  bool isLoading = true;
  String? errorMessage;
  String query = '';

  List<FriendStatus> get visibleFriends {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return _friends;
    return _friends
        .where((friend) => friend.name.toLowerCase().contains(normalized))
        .toList(growable: false);
  }

  void setQuery(String value) {
    query = value;
    notifyListeners();
  }

  /// Consulta /friends/gaps para que el backend registre el evento "viewed"
  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      _friends = await _friendsService.loadAvailableFriends();
    } catch (_) {
      errorMessage = 'No pudimos cargar tus amigos.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> sendRequest(String email) async {
    try {
      await _friendsService.sendRequest(email.trim());
      return null;
    } catch (error) {
      final message = error.toString();
      return message.startsWith('Exception: ')
          ? message.substring('Exception: '.length)
          : message;
    }
  }
}

class ActivityCreationViewModel extends ChangeNotifier {
  ActivityCreationViewModel({
    List<String>? initialFriends,
    this.freeTimeMinutes,
    ActivityRepository? repository,
    FriendsService? friendsService,
    ActivityService? activityService,
    LocationService? locationService,
    DateTime Function()? now,
    this.source,
  }) : selectedFriends = (initialFriends ?? const [])
           .map((friend) => friend.trim().toLowerCase())
           .toList(),
       _repository = repository ?? ActivityRepository(),
       _friendsService = friendsService ?? FriendsService(),
       _activityService = activityService ?? ActivityService(),
       _locationService = locationService ?? LocationService(),
       _now = now ?? DateTime.now;

  final ActivityRepository _repository;
  final FriendsService _friendsService;
  final ActivityService _activityService;
  final LocationService _locationService;
  final DateTime Function() _now;
  final String? source;
  final int? freeTimeMinutes;

  // Contains stable identifiers (email when available), not display names.
  final List<String> selectedFriends;
  CategoryOption? selectedCategory;
  PlaceOption? selectedPlace;

  bool isSubmitting = false;
  String? errorMessage;
  Activity? createdActivity;
  bool savedOffline = false;

  // ---------- Step 1: amigos reales ----------
  List<FriendStatus> availableFriends = const [];
  bool isLoadingFriends = true;
  String? friendsError;

  List<FriendStatus> get selectedAvailableFriends => availableFriends
      .where(isFriendSelected)
      .toList(growable: false);

  List<String> get selectedFriendNames => selectedAvailableFriends
      .map((friend) => friend.name)
      .toList(growable: false);

  bool isFriendSelected(FriendStatus friend) =>
      selectedFriends.contains(_friendIdentifier(friend));

  Future<void> loadFriends() async {
    isLoadingFriends = true;
    friendsError = null;
    notifyListeners();
    try {
      availableFriends = await _friendsService.loadAvailableFriends();
      final availableIds = availableFriends.map(_friendIdentifier).toSet();
      selectedFriends.retainWhere(availableIds.contains);
    } catch (_) {
      friendsError = 'No pudimos cargar a tus amigos.';
    } finally {
      isLoadingFriends = false;
      notifyListeners();
    }
  }

  // ---------- Step 3: lugares reales (cerca de ti) ----------
  List<PlaceOption> _places = const [];
  bool isLoadingPlaces = true;
  String? placesError;
  String placeQuery = '';

  List<PlaceOption> get visiblePlaces {
    final normalized = placeQuery.trim().toLowerCase();
    if (normalized.isEmpty) return _places;
    return _places
        .where((place) => place.name.toLowerCase().contains(normalized))
        .toList(growable: false);
  }

  void setPlaceQuery(String value) {
    placeQuery = value;
    notifyListeners();
  }

  Future<void> loadPlaces() async {
    isLoadingPlaces = true;
    placesError = null;
    notifyListeners();
    try {
      final result = await _locationService.current();
      final where = result.location;
      if (where == null) {
        placesError = 'Turn on your location to see nearby places.';
      } else {
        _places = await _activityService.getNearbyPlaces(
          lat: where.lat,
          lon: where.lon,
        );
      }
    } on ActivityException catch (error) {
      placesError = error.message;
    } catch (_) {
      placesError = 'We could not load nearby places.';
    } finally {
      isLoadingPlaces = false;
      notifyListeners();
    }
  }

  void toggleFriend(FriendStatus friend) {
    final identifier = _friendIdentifier(friend);
    if (identifier.isEmpty ||
        !availableFriends.any(
          (availableFriend) =>
              _friendIdentifier(availableFriend) == identifier,
        )) {
      return;
    }

    selectedFriends.contains(identifier)
        ? selectedFriends.remove(identifier)
        : selectedFriends.add(identifier);
    notifyListeners();
  }

  void selectCategory(CategoryOption category) {
    selectedCategory = category;
    notifyListeners();
  }

  void selectPlace(PlaceOption place) {
    selectedPlace = place;
    notifyListeners();
  }

  String? get validationError {
    // Una actividad puede ser individual; invitar amigos es opcional.
    if (selectedCategory == null) return 'Choose a type of activity.';
    if (selectedPlace == null) return 'Choose a place.';
    return null;
  }

  bool get canSubmit => validationError == null;

  Future<bool> submit() async {
    final error = validationError;
    if (error != null) {
      errorMessage = error;
      notifyListeners();
      return false;
    }

    isSubmitting = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await _repository.create(_buildDraft(), source: source);
      createdActivity = result.activity;
      savedOffline = result.savedOffline;
      return true;
    } on ActivityException catch (error) {
      errorMessage = error.message;
      return false;
    } catch (_) {
      errorMessage = 'No pudimos crear la actividad. Inténtalo de nuevo.';
      return false;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  ActivityDraft _buildDraft() {
    final place = selectedPlace!;
    final category = selectedCategory!;
    final start = _now().add(const Duration(minutes: 30));
    final availableFriendIds = availableFriends.map(_friendIdentifier).toSet();
    final selectedAvailableFriendsCount = selectedFriends
        .toSet()
        .intersection(availableFriendIds)
        .length;
    final freeTime = freeTimeMinutes;
    return ActivityDraft(
      clientId: const Uuid().v4(),
      attemptId: freeTime != null && freeTime >= 0
          ? const Uuid().v4()
          : null,
      title: '${category.label} at ${place.name}',
      category: category.backendValue,
      startTime: start,
      endTime: start.add(Duration(minutes: place.durationMinutes)),
      locationName: place.name,
      latitude: place.latitude,
      longitude: place.longitude,
      friends: selectedFriendNames,
      price: place.price,
      capacity: place.capacity,
      aboutLocation: place.description,
      imageUrl: place.imageUrl,
      planCreationContext: PlanCreationContext(
        preferences: [category.backendValue],
        freeTimeMinutes: freeTimeMinutes,
        locationName: place.name,
        latitude: place.latitude,
        longitude: place.longitude,
        availableFriendsCount: availableFriends.length,
        selectedAvailableFriendsCount: selectedAvailableFriendsCount,
      ),
    );
  }
}

String _friendIdentifier(FriendStatus friend) {
  final email = friend.email?.trim().toLowerCase();
  return email == null || email.isEmpty
      ? friend.name.trim().toLowerCase()
      : email;
}