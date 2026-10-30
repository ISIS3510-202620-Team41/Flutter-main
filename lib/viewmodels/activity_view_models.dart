import 'package:flutter/foundation.dart';

import '../data/mock_data.dart';
import '../models/activity.dart';
import '../services/activity_service.dart';
import '../services/location_service.dart';
import '../models/activity_record.dart';

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
    errorMessage = null;

    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      _activities = await _activityService.getCachedActivities();

      if (_activities.isNotEmpty) {
        isLoading = false;
        notifyListeners();
      }
    } catch (_) {
      // Continuamos con la recuperacion remota de actividades
    }

    try {
      final where = await _locationService.current();

      if (!where.isFallback) {
        final nearbyCached = await _activityService.getCachedActivities(
          lat: where.lat,
          lon: where.lon,
        );
        _activities = nearbyCached;
        isLoading = false;
        notifyListeners();
      }

      final updatedActivites = await _activityService.getNearby(
        lat: where.lat,
        lon: where.lon,
      );

      _activities = updatedActivites;
      errorMessage = null;
    } on ActivityException catch (error) {
        if (_activities.isEmpty) {
        errorMessage = error.message;}
    } catch (_) {
      if (_activities.isEmpty) {
      errorMessage = 'No pudimos cargar las actividades cercanas.';}
    } finally {
      isLoading = false;
      notifyListeners();
    }
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

class ActivityDetailViewModel extends ChangeNotifier {
  ActivityDetailViewModel({
    ActivityService? activityService,
  }) : _activityService = activityService ?? ActivityService();

  final ActivityService _activityService;

  ActivityRecord? activity;

  bool isLoading = true;
  bool isRefreshing = false;

  String? errorMessage;
  String? refreshErrorMessage;

  String? _activityId;
  bool _disposed = false;

  Future<void> load(String? id) async {
    _activityId = id;

    if (id == null || id.trim().isEmpty) {
      isLoading = false;
      errorMessage = 'No se proporcionó una actividad válida.';
      _notifyIfAlive();
      return;
    }

    errorMessage = null;
    refreshErrorMessage = null;

    isLoading = activity == null;
    isRefreshing = activity != null;

    _notifyIfAlive();

    // Obtenemos desde cache primero
    try {
      final cached = await _activityService.getCachedActivityById(id);

      if (_disposed) return;

      if (cached != null) {
        activity = cached;
        isLoading = false;
        isRefreshing = true;

        _notifyIfAlive();
      }
    } catch (_) {
    }

    // Solicitamos version actualizada al back
    try {
      final updated = await _activityService.getActivityById(id);

      if (_disposed) return;

      activity = updated;
      refreshErrorMessage = null;
      errorMessage = null;
    } on ActivityException catch (error) {
      if (_disposed) return;

      if (activity == null) {
        errorMessage = error.message;
      } else {
        refreshErrorMessage = error.message;
      }
    } catch (_) {
      if (_disposed) return;

      if (activity == null) {
        errorMessage = 'No pudimos cargar los detalles de la actividad.';
      } else {
        refreshErrorMessage =
            'No fue posible actualizar los detalles. '
            'Se conserva la información guardada.';
      }
    } finally {
      if (!_disposed) {
        isLoading = false;
        isRefreshing = false;
        _notifyIfAlive();
      }
    }
  }

  Future<void> retry() => load(_activityId);

  void _notifyIfAlive() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class ActivityCreatedViewModel {
  const ActivityCreatedViewModel();

  Activity get activity => bistro;
}
