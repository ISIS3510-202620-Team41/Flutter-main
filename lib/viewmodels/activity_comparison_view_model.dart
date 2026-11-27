import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/activity_comparison_criteria.dart';
import '../models/activity_comparison_result.dart';
import '../models/activity_record.dart';
import '../services/activity_comparison_service.dart';
import '../services/connectivity_service.dart';
import '../services/location_service.dart';

class ActivityComparisonViewModel extends ChangeNotifier {
  ActivityComparisonViewModel({
    ActivityComparisonService? comparisonService,
    ConnectivityService? connectivityService,
  }) : _comparisonService = comparisonService ?? ActivityComparisonService(),
       _connectivityService =
           connectivityService ?? ConnectivityService.instance {
    _connectivitySubscription = _connectivityService.onConnectivityChanged
        .listen(_onConnectivityChanged);
  }

  static const maximumActivities = 10;

  final ActivityComparisonService _comparisonService;
  final ConnectivityService _connectivityService;
  late final StreamSubscription<bool> _connectivitySubscription;

  ActivityComparisonActivityData? _activityData;
  String _userId = 'anonymous';
  int _calculationRequest = 0;
  bool _disposed = false;
  bool _refreshInProgress = false;

  List<ActivityRecord> availableActivities = const [];
  List<String> selectedActivityIds = const [];
  Set<String> preferredCategories = const {};
  ActivityComparisonCriteria criteria = const ActivityComparisonCriteria();
  List<ActivityComparisonResult> results = const [];

  bool isLoading = true;
  bool isRefreshing = false;
  bool isCalculating = false;
  bool isOffline = false;
  bool isStale = false;
  bool isUsingCachedResult = false;
  String? errorMessage;
  String? refreshError;

  LocationIssue? get locationIssue => _activityData?.locationIssue;

  List<ActivityRecord> get selectedActivities {
    final byId = {
      for (final activity in availableActivities) activity.id: activity,
    };
    return selectedActivityIds
        .map((id) => byId[id])
        .whereType<ActivityRecord>()
        .toList(growable: false);
  }

  List<String> get availableLocations {
    final locations =
        availableActivities
            .map((activity) => activity.locationName.trim())
            .where((location) => location.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final selectedLocation = criteria.preferredLocation;
    if (selectedLocation != null &&
        selectedLocation.isNotEmpty &&
        !locations.contains(selectedLocation)) {
      locations.add(selectedLocation);
      locations.sort();
    }
    return locations;
  }

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    refreshError = null;
    _notifyIfAlive();

    try {
      _userId = await _comparisonService.userId;
      preferredCategories = await _comparisonService.loadPreferredCategories(
        _userId,
      );
      final activityData = await _comparisonService.loadAvailableActivities();
      _applyActivityData(activityData);
      isLoading = false;
      _notifyIfAlive();

      if (_connectivityService.isOnline == true) {
        unawaited(refreshActivities());
      }
    } on Exception catch (error) {
      errorMessage = error.toString();
      isLoading = false;
      _notifyIfAlive();
    }
  }

  Future<void> setSelectedActivityIds(Iterable<String> ids) async {
    final uniqueIds = ids.toSet().toList(growable: false);
    if (uniqueIds.length > maximumActivities) {
      throw ArgumentError('A comparison can contain at most 10 activities.');
    }

    final availableIds = availableActivities
        .map((activity) => activity.id)
        .toSet();
    selectedActivityIds = uniqueIds
        .where(availableIds.contains)
        .toList(growable: false);
    results = const [];
    isStale = _activityData?.isStale ?? false;
    isUsingCachedResult = false;
    _notifyIfAlive();
    await _calculate();
  }

  void updateWeight(ActivityComparisonCriterion criterion, int value) {
    criteria = criteria.withWeight(criterion, value);
    _notifyIfAlive();
  }

  Future<void> commitWeights() => _calculate();

  Future<void> setPreferredLocation(String? location) async {
    criteria = criteria.withPreferredLocation(location);
    _notifyIfAlive();
    await _calculate();
  }

  Future<void> refreshActivities() async {
    final previous = _activityData;
    if (previous == null || _refreshInProgress) return;

    _refreshInProgress = true;
    isRefreshing = true;
    refreshError = null;
    _notifyIfAlive();

    try {
      final updated = await _comparisonService.refreshAvailableActivities(
        previous,
      );
      _applyActivityData(updated);

      final availableIds = availableActivities
          .map((activity) => activity.id)
          .toSet();
      selectedActivityIds = selectedActivityIds
          .where(availableIds.contains)
          .toList(growable: false);
      if (selectedActivityIds.length >= 2) {
        await _calculate();
      }
    } on Exception catch (error) {
      refreshError = error.toString();
    } finally {
      _refreshInProgress = false;
      isRefreshing = false;
      _notifyIfAlive();
    }
  }

  void _applyActivityData(ActivityComparisonActivityData data) {
    _activityData = data;
    availableActivities = data.activities;
    isOffline = data.isOffline;
    refreshError = data.refreshError;
    isStale = data.isStale;
  }

  void _onConnectivityChanged(bool online) {
    isOffline = !online;
    _notifyIfAlive();
    if (online) unawaited(refreshActivities());
  }

  Future<void> _calculate() async {
    final request = ++_calculationRequest;
    final selected = selectedActivities;
    if (selected.length < 2) {
      results = const [];
      isCalculating = false;
      isStale = _activityData?.isStale ?? false;
      _notifyIfAlive();
      return;
    }

    final activityData = _activityData;
    if (activityData == null) return;

    isCalculating = true;
    errorMessage = null;
    isUsingCachedResult = false;
    _notifyIfAlive();

    try {
      final calculation = await _comparisonService.compare(
        activities: selected,
        criteria: criteria,
        preferredCategories: preferredCategories,
        userId: _userId,
        referenceLocation: activityData.referenceLocation,
        isOffline: isOffline,
      );
      if (_disposed || request != _calculationRequest) return;

      results = calculation.results;
      isStale = calculation.isStale;
      isUsingCachedResult = calculation.fromCache;
    } on Exception catch (error) {
      if (_disposed || request != _calculationRequest) return;
      errorMessage = error.toString();
      results = const [];
    } finally {
      if (!_disposed && request == _calculationRequest) {
        isCalculating = false;
        _notifyIfAlive();
      }
    }
  }

  void _notifyIfAlive() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _calculationRequest++;
    unawaited(_connectivitySubscription.cancel());
    super.dispose();
  }
}
