import 'package:flutter/foundation.dart';

import '../data/mock_data.dart';
import '../models/activity.dart';
import '../services/activity_service.dart';
import '../services/location_service.dart';
import 'dart:async';
import '../cache/activity_image_cache.dart';

class ActivitiesViewModel extends ChangeNotifier {
  ActivitiesViewModel({
    ActivityService? activityService,
    LocationService? locationService,
  })  : _activityService = activityService ?? ActivityService(),
        _locationService = locationService ?? LocationService();

  final ActivityService _activityService;
  final LocationService _locationService;

  static const allCategories = 'Todas';
  static const categories = [allCategories, ...activityCategoryLabels];

  String query = '';
  String selectedCategory = allCategories;

  List<Activity> _activities = const [];
  bool isLoading = true;
  bool showingCached = false;
  String? errorMessage;

  List<Activity> get visibleActivities {
    final normalizedQuery = query.trim().toLowerCase();
    return _activities
        .where((activity) {
          final matchesCategory =
              selectedCategory == allCategories||
              activity.category.toLowerCase() == selectedCategory.toLowerCase();
          final matchesQuery =
              normalizedQuery.isEmpty ||
              activity.name.toLowerCase().contains(normalizedQuery);
          return matchesCategory && matchesQuery;
        })
        .toList(growable: false);
  }

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    showingCached = false;
    notifyListeners();
    try {
      final where = await _locationService.current();
      _activities = await _activityService.getNearby(
        lat: where.lat,
        lon: where.lon,
      );
      unawaited(ActivityImageCacheManager.prefetch(
        _activities.map((activity) => activity.imageUrl),
      ));
    } on ActivityException catch (error) {
      errorMessage = error.message;
    } catch (_) {
      errorMessage = 'No pudimos cargar las actividades cercanas.';
    } finally {
      isLoading = false;
      notifyListeners();
    }

  }
  Future<void> _showSavedOr(String message) async {
    final saved = await _activityService.getCachedActivities();
    if (saved.isEmpty) {
      errorMessage = message;
      return;
    }
    _activities = saved;
    showingCached = true;
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
