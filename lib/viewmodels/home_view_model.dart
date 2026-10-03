import 'package:flutter/foundation.dart';

import '../models/activity.dart';
import '../models/profile_models.dart';
import '../services/profile_service.dart';
import '../services/schedule_service.dart';
import '../services/activity_service.dart';
import '../services/location_service.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    ProfileService? profileService,
    ScheduleService? scheduleService,
    ActivityService? activityService,
    LocationService? locationService,
    DateTime Function()? now,
  })  : _profileService = profileService ?? ProfileService(),
        _scheduleService = scheduleService ?? ScheduleService(),
        _activityService = activityService ?? ActivityService(),
        _locationService = locationService ?? LocationService(),
        _now = now ?? DateTime.now;

  final ProfileService _profileService;
  final ScheduleService _scheduleService;
  final ActivityService _activityService;
  final LocationService _locationService;
  final DateTime Function() _now;

  UserProfile? profile;
  FreeInterval? nextFreeInterval;
  bool isLoading = true;
  String? errorMessage;

  List<Activity> recommendations = const [];
  String? recommendationId;
  int? recommendationFreeMinutes;
  String? recommendationsError;
  String? actionMessage;

  String get greetingName {
    final name = profile?.name.trim() ?? '';
    return name.isEmpty ? 'allí' : name.split(RegExp(r'\s+')).first;
  }

  int get freeMinutes {
    final interval = nextFreeInterval;
    if (interval == null) return 0;
    return interval.end.difference(interval.start).inMinutes;
  }

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    recommendations = const [];
    recommendationId = null;
    recommendationFreeMinutes = null;
    recommendationsError = null;
    actionMessage = null;
    notifyListeners();
    try {
      profile = await _profileService.getCurrentUser();
      final date = _now();
      final gaps = await _scheduleService.getGaps(
        date: DateTime(date.year, date.month, date.day),
      );
      final now = _now();
      final upcoming = gaps.free.where((gap) => gap.end.isAfter(now)).toList()
        ..sort((a, b) => a.start.compareTo(b.start));
      nextFreeInterval = upcoming.isEmpty ? null : upcoming.first;
    } on ProfileException catch (error) {
      errorMessage = error.message;
    } on ScheduleException catch (error) {
      errorMessage = error.message;
    } catch (_) {
      errorMessage = 'No pudimos cargar tu información. Intenta de nuevo.';
    } finally {
      await _loadRecommendations();
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadRecommendations() async {
    recommendationsError = null;
    try {
      final where = await _locationService.current();
      final batch = await _activityService.getRecommendations(
        lat: where.lat,
        lon: where.lon,
      );
      recommendations = batch.activities;
      recommendationId = batch.recommendationId;
      recommendationFreeMinutes = batch.freeMinutes;
    } on ActivityException catch (error) {
      recommendations = const [];
      recommendationsError = error.message;
    } catch (_) {
      recommendations = const [];
      recommendationsError = 'No pudimos cargar las recomendaciones.';
    }
  }
  Future<bool> choose(Activity activity) async {
    final id = activity.id;
    if (id == null) return false;
    actionMessage = null;
    try {
      await _activityService.join(
        id,
        recommendationId: recommendationId,
        freeTimeMinutes: recommendationFreeMinutes,
      );
      recommendations = recommendations.where((a) => a.id != id).toList();
      notifyListeners();
      return true;
    } on ActivityException catch (error) {
      actionMessage = error.message;
    } catch (_) {
      actionMessage = 'No pudimos unirte a la actividad.';
    }
    notifyListeners();
    return false;
  }
}

String formatClockTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}
