import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../cache/activity_comparison_cache.dart';
import '../models/activity_comparison_criteria.dart';
import '../models/activity_comparison_result.dart';
import '../models/activity_record.dart';
import '../repositories/activity_local_repository.dart';
import '../repositories/category_preferences_repository.dart';
import '../services/activity_service.dart';
import '../services/activity_comparison_worker.dart';
import '../services/connectivity_service.dart';
import '../services/location_service.dart';
import '../services/session_user.dart';

class ActivityComparisonActivityData {
  const ActivityComparisonActivityData({
    required this.activities,
    required this.referenceLocation,
    required this.locationIssue,
    required this.isOffline,
    this.refreshError,
  });

  final List<ActivityRecord> activities;
  final UserLocation? referenceLocation;
  final LocationIssue? locationIssue;
  final bool isOffline;
  final String? refreshError;

  bool get isStale {
    final now = DateTime.now().toUtc();
    return activities.any((activity) {
          final age = now.difference(activity.cachedAt.toUtc());
          return age.isNegative ||
              age > ActivityComparisonService.dataFreshness;
        }) ||
        (referenceLocation?.source != null &&
            referenceLocation!.source != LocationSource.current);
  }
}

class ActivityComparisonCalculation {
  const ActivityComparisonCalculation({
    required this.results,
    required this.calculatedAt,
    required this.fromCache,
    required this.isStale,
  });

  final List<ActivityComparisonResult> results;
  final DateTime calculatedAt;
  final bool fromCache;
  final bool isStale;
}

class ActivityComparisonService {
  ActivityComparisonService({
    ActivityService? activityService,
    ActivityLocalRepository? localRepository,
    LocationService? locationService,
    ConnectivityService? connectivityService,
    CategoryPreferencesRepository? categoryPreferencesRepository,
    ActivityComparisonCache? comparisonCache,
    Future<String?> Function()? userId,
    DateTime Function()? now,
  }) : _activityService =
           activityService ?? ActivityService(localRepository: localRepository),
       _locationService = locationService ?? LocationService(),
       _connectivityService =
           connectivityService ?? ConnectivityService.instance,
       _categoryPreferencesRepository =
           categoryPreferencesRepository ?? CategoryPreferencesRepository(),
       _comparisonCache = comparisonCache ?? ActivityComparisonCache(),
       _userId = userId ?? currentUserId,
       _now = now ?? DateTime.now;

  static const dataFreshness = Duration(hours: 24);
  static const searchRadiusKm = 5.0;

  final ActivityService _activityService;
  final LocationService _locationService;
  final ConnectivityService _connectivityService;
  final CategoryPreferencesRepository _categoryPreferencesRepository;
  final ActivityComparisonCache _comparisonCache;
  final Future<String?> Function() _userId;
  final DateTime Function() _now;

  Future<String> get userId async => await _userId() ?? 'anonymous';

  Future<Set<String>> loadPreferredCategories(String userId) =>
      _categoryPreferencesRepository.load(userId);

  Future<ActivityComparisonActivityData> loadAvailableActivities() async {
    final records = await _activityService.getCachedActivityRecords();
    final location = await _locationService.current();
    return _buildActivityData(
      records: records,
      referenceLocation: location.location,
      locationIssue: location.issue,
      isOffline: _connectivityService.isOnline == false,
    );
  }

  Future<ActivityComparisonActivityData> refreshAvailableActivities(
    ActivityComparisonActivityData previous,
  ) async {
    final isOffline = _connectivityService.isOnline == false;
    if (isOffline) {
      return _buildActivityData(
        records: previous.activities,
        referenceLocation: previous.referenceLocation,
        locationIssue: previous.locationIssue,
        isOffline: true,
        refreshError: previous.refreshError,
      );
    }

    final location = await _locationService.current();
    final referenceLocation = location.location;
    if (referenceLocation == null) {
      return _buildActivityData(
        records: previous.activities,
        referenceLocation: null,
        locationIssue: location.issue,
        isOffline: false,
        refreshError: 'Activa la ubicación para actualizar las actividades.',
      );
    }

    try {
      await _activityService.refreshNearby(
        lat: referenceLocation.lat,
        lon: referenceLocation.lon,
        radiusKm: searchRadiusKm,
      );
      final records = await _activityService.getCachedActivityRecords();
      return _buildActivityData(
        records: records,
        referenceLocation: referenceLocation,
        locationIssue: location.issue,
        isOffline: false,
      );
    } on Exception catch (error) {
      return _buildActivityData(
        records: previous.activities,
        referenceLocation: referenceLocation,
        locationIssue: location.issue,
        isOffline: false,
        refreshError: error.toString(),
      );
    }
  }

  Future<ActivityComparisonCalculation> compare({
    required List<ActivityRecord> activities,
    required ActivityComparisonCriteria criteria,
    required Set<String> preferredCategories,
    required String userId,
    required UserLocation? referenceLocation,
    required bool isOffline,
  }) async {
    if (activities.length < 2 || activities.length > 10) {
      throw ArgumentError('A comparison requires between 2 and 10 activities.');
    }

    final ids = activities.map((activity) => activity.id).toSet();
    if (ids.length != activities.length) {
      throw ArgumentError('Comparison activity IDs must be unique.');
    }
    if (criteria.totalWeight != 100) {
      throw ArgumentError('Comparison weights must total 100.');
    }

    final key = _cacheKey(
      activities: activities,
      criteria: criteria,
      preferredCategories: preferredCategories,
      referenceLocation: referenceLocation,
    );
    final cached = await _comparisonCache.get(
      userId: userId,
      key: key,
      allowStale: isOffline,
    );
    final staleData =
        isOffline ||
        _isDataStale(activities) ||
        (referenceLocation != null &&
            referenceLocation.source != LocationSource.current);
    if (cached != null) {
      return ActivityComparisonCalculation(
        results: cached.results,
        calculatedAt: cached.createdAt,
        fromCache: true,
        isStale: staleData || cached.isStale,
      );
    }

    final payload = <String, Object?>{
      'records': activities.map((activity) => activity.toMap()).toList(),
      'weights': {
        for (final criterion in ActivityComparisonCriterion.values)
          criterion.key: criteria.weights[criterion],
      },
      'preferredCategories': preferredCategories.toList()..sort(),
      'preferredLocation': criteria.preferredLocation,
      'referenceLatitude': referenceLocation?.lat,
      'referenceLongitude': referenceLocation?.lon,
    };
    final rawResults =
        await compute<Map<String, Object?>, List<Map<String, Object?>>>(
          compareActivitiesInWorker,
          payload,
          debugLabel: 'activity-comparison-scoring',
        );
    final results = rawResults
        .map(ActivityComparisonResult.fromMap)
        .toList(growable: false);
    final calculatedAt = _now().toUtc();

    await _comparisonCache.put(userId: userId, key: key, results: results);

    return ActivityComparisonCalculation(
      results: results,
      calculatedAt: calculatedAt,
      fromCache: false,
      isStale: staleData,
    );
  }

  ActivityComparisonActivityData _buildActivityData({
    required List<ActivityRecord> records,
    required UserLocation? referenceLocation,
    required LocationIssue? locationIssue,
    required bool isOffline,
    String? refreshError,
  }) {
    final now = _now();
    final available =
        records
            .where((record) {
              final endTime = DateTime.tryParse(record.endTime);
              return endTime == null || endTime.isAfter(now);
            })
            .toList(growable: false)
          ..sort((left, right) {
            final timeOrder = left.startTime.compareTo(right.startTime);
            return timeOrder != 0 ? timeOrder : left.id.compareTo(right.id);
          });

    return ActivityComparisonActivityData(
      activities: List.unmodifiable(available),
      referenceLocation: referenceLocation,
      locationIssue: locationIssue,
      isOffline: isOffline,
      refreshError: refreshError,
    );
  }

  bool _isDataStale(List<ActivityRecord> activities) {
    final now = _now().toUtc();
    return activities.any((activity) {
      final age = now.difference(activity.cachedAt.toUtc());
      return age.isNegative || age > dataFreshness;
    });
  }

  String _cacheKey({
    required List<ActivityRecord> activities,
    required ActivityComparisonCriteria criteria,
    required Set<String> preferredCategories,
    required UserLocation? referenceLocation,
  }) {
    final orderedActivities = List<ActivityRecord>.of(activities)
      ..sort((left, right) => left.id.compareTo(right.id));

    return jsonEncode({
      'algorithmVersion': 1,
      'activities': orderedActivities
          .map(
            (activity) => {
              'id': activity.id,
              'category': activity.category,
              'startTime': activity.startTime,
              'endTime': activity.endTime,
              'price': activity.price,
              'locationName': activity.locationName,
              'latitude': activity.latitude,
              'longitude': activity.longitude,
              'participants': activity.participants,
              'capacity': activity.capacity,
            },
          )
          .toList(),
      'weights': {
        for (final criterion in ActivityComparisonCriterion.values)
          criterion.key: criteria.weights[criterion],
      },
      'preferredCategories': preferredCategories.toList()..sort(),
      'preferredLocation': criteria.preferredLocation?.trim().toLowerCase(),
      'referenceLocation': referenceLocation == null
          ? null
          : {
              'latitude': referenceLocation.lat,
              'longitude': referenceLocation.lon,
            },
    });
  }
}
