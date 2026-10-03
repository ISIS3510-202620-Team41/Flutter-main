import 'package:flutter/foundation.dart';

import '../data/mock_data.dart';
import '../models/activity.dart';

class ActivitiesViewModel extends ChangeNotifier {
  String query = '';
  String selectedCategory = 'Comida';

  List<Activity> get visibleActivities {
    final normalizedQuery = query.trim().toLowerCase();
    return nearbyActivities
        .where((activity) {
          final matchesCategory =
              selectedCategory == 'Comida' ||
              activity.category.toLowerCase() == selectedCategory.toLowerCase();
          final matchesQuery =
              normalizedQuery.isEmpty ||
              activity.name.toLowerCase().contains(normalizedQuery);
          return matchesCategory && matchesQuery;
        })
        .toList(growable: false);
  }

  void setQuery(String value) {
    query = value;
    notifyListeners();
  }

  void selectCategory(String category) {
    selectedCategory = category;
    notifyListeners();
  }
}

class ActivityDetailViewModel {
  const ActivityDetailViewModel();

  Activity get activity => bistro;
}

class ActivityCreatedViewModel {
  const ActivityCreatedViewModel();

  Activity get activity => bistro;
}
