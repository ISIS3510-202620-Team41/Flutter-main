import 'package:flutter/foundation.dart';

import '../models/profile_models.dart';
import '../services/profile_service.dart';
import '../services/schedule_service.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    ProfileService? profileService,
    ScheduleService? scheduleService,
    DateTime Function()? now,
  })  : _profileService = profileService ?? ProfileService(),
        _scheduleService = scheduleService ?? ScheduleService(),
        _now = now ?? DateTime.now;

  final ProfileService _profileService;
  final ScheduleService _scheduleService;
  final DateTime Function() _now;

  UserProfile? profile;
  FreeInterval? nextFreeInterval;
  bool isLoading = true;
  String? errorMessage;

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
      isLoading = false;
      notifyListeners();
    }
  }
}

String formatClockTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}
