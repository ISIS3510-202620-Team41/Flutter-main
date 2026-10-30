import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/mock_data.dart';
import '../models/activity.dart';
import '../models/activity_draft.dart';
import '../repositories/activity_repository.dart';
import '../services/activity_service.dart';

class FriendsViewModel extends ChangeNotifier {
  String query = '';

  List<FriendStatus> get visibleFriends {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return friends;
    return friends
        .where((friend) => friend.name.toLowerCase().contains(normalized))
        .toList(growable: false);
  }

  void setQuery(String value) {
    query = value;
    notifyListeners();
  }
}

class ActivityCreationViewModel extends ChangeNotifier {
  ActivityCreationViewModel({
    List<String>? initialFriends,
    ActivityRepository? repository,
    DateTime Function()? now,
  })  : selectedFriends = [...(initialFriends ?? const ['Alex'])],
        _repository = repository ?? ActivityRepository(),
        _now = now ?? DateTime.now;

  final ActivityRepository _repository;
  final DateTime Function() _now;

  final List<String> selectedFriends;
  CategoryOption? selectedCategory;
  PlaceOption? selectedPlace;

  bool isSubmitting = false;
  String? errorMessage;
  Activity? createdActivity;
  bool savedOffline = false;

  void toggleFriend(String friend) {
    selectedFriends.contains(friend)
        ? selectedFriends.remove(friend)
        : selectedFriends.add(friend);
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
    if (selectedFriends.isEmpty) return 'Select at least one friend.';
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
      final result = await _repository.create(_buildDraft());
      createdActivity = result.activity;
      savedOffline = result.savedOffline;
      return true;
    } on ActivityException catch (error) {
      errorMessage = error.message;
      return false;
    } catch (_) {
      errorMessage = 'We could not create the activity. Try again.';
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
    return ActivityDraft(
      clientId: const Uuid().v4(),
      title: '${category.label} at ${place.name}',
      category: category.backendValue,
      startTime: start,
      endTime: start.add(Duration(minutes: place.durationMinutes)),
      locationName: place.name,
      latitude: place.latitude,
      longitude: place.longitude,
      friends: List<String>.from(selectedFriends),
      price: place.price,
      capacity: place.capacity,
      aboutLocation: place.description,
      imageUrl: place.imageUrl,
    );
  }
}
