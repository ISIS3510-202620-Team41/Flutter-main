import 'dart:async';

import 'package:flutter/foundation.dart';

import '../cache/activity_image_cache.dart';
import '../data/mock_data.dart';
import '../models/activity.dart';
import '../services/activity_service.dart';
import '../services/location_service.dart';

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

  /// True when the list comes from SQLite because the request failed.
  bool showingCached = false;
  String? errorMessage;

  List<Activity> get visibleActivities {
    final normalizedQuery = query.trim().toLowerCase();
    return _activities
        .where((activity) {
      final matchesCategory =
          selectedCategory == allCategories ||
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
      // getNearby also saves the activities in SQLite and in the memory cache.
      _activities = await _activityService.getNearby(
        lat: where.lat,
        lon: where.lon,
      );
      // Download the photos in the background so they work offline later.
      unawaited(ActivityImageCacheManager.prefetch(
        _activities.map((activity) => activity.imageUrl),
      ));
    } on ActivityException catch (error) {
      await _showSavedOr(error.message);
    } catch (_) {
      await _showSavedOr('No pudimos cargar las actividades cercanas.');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// If the request failed but SQLite has activities, show them instead of
  /// an error screen.
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