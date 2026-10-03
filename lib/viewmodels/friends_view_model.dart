import 'package:flutter/foundation.dart';

import '../data/mock_data.dart';
import '../models/activity.dart';

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
  ActivityCreationViewModel({List<String>? initialFriends})
      : selectedFriends = [...(initialFriends ?? const ['Alex'])];

  final List<String> selectedFriends;
  final List<String> categories = const [
    'Food',
    'Plays',
    'Music',
    'Study',
    'Sport',
    'Cultural',
  ];
  final List<String> selectedCategories = ['Food'];
  String selectedPlace = 'Bistro';

  void toggleFriend(String friend) {
    selectedFriends.contains(friend)
        ? selectedFriends.remove(friend)
        : selectedFriends.add(friend);
    notifyListeners();
  }

  void toggleCategory(String category) {
    selectedCategories.contains(category)
        ? selectedCategories.remove(category)
        : selectedCategories.add(category);
    notifyListeners();
  }

  void selectPlace(String place) {
    selectedPlace = place;
    notifyListeners();
  }
}
