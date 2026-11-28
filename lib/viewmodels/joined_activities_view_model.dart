import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../models/joined_activity_record.dart';
import '../models/pending_action.dart';
import '../repositories/joined_activities_repository.dart';
import '../services/activity_service.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../services/pending_actions_sync_service.dart';
import '../services/notification_service.dart';

class JoinedActivitiesViewModel extends ChangeNotifier {
  JoinedActivitiesViewModel(
    this._repository, {
    ActivityService? activityService,
    AuthService? authService,
    ConnectivityService? connectivityService,
    PendingActionsSyncService? syncService,
    DateTime Function()? now,
    Future<void> Function()? syncCurrentUserPlans,
  }) : _activityService = activityService ?? ActivityService(),
       _authService = authService ?? AuthService(),
       _connectivityService =
           connectivityService ?? ConnectivityService.instance,
       _syncService = syncService ?? PendingActionsSyncService.instance,
       _syncCurrentUserPlans =
           syncCurrentUserPlans ??
           NotificationService.instance.syncCurrentUserPlans,
       _now = now ?? DateTime.now {
    _connectivitySubscription = _connectivityService.onConnectivityChanged
        .listen(_onConnectivityChanged);
    _syncSubscription = _syncService.onActionSynced.listen(_onActionSynced);
  }

  final JoinedActivitiesRepository _repository;
  final ActivityService _activityService;
  final AuthService _authService;
  final ConnectivityService _connectivityService;
  final PendingActionsSyncService _syncService;
  final Future<void> Function() _syncCurrentUserPlans;
  final DateTime Function() _now;
  late final StreamSubscription<bool> _connectivitySubscription;
  late final StreamSubscription<PendingAction> _syncSubscription;

  String? _userId;
  bool _disposed = false;
  bool _refreshInProgress = false;
  final Set<String> _leavingActivityIds = {};

  List<JoinedActivityRecord> activities = const [];
  bool isLoading = true;
  bool isRefreshing = false;
  bool isOffline = false;
  bool pastActivitiesExpanded = false;
  String? errorMessage;
  String? refreshError;

  List<JoinedActivityRecord> get upcomingActivities {
    final result = activities.where((item) => !_isPast(item)).toList()
      ..sort((left, right) {
        return left.activity.startTime.compareTo(right.activity.startTime);
      });
    return result;
  }

  List<JoinedActivityRecord> get pastActivities {
    final result = activities.where(_isPast).toList()
      ..sort((left, right) {
        return right.activity.startTime.compareTo(left.activity.startTime);
      });
    return result;
  }

  bool get isEmpty => activities.isEmpty;

  bool isLeaving(String activityId) => _leavingActivityIds.contains(activityId);

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    refreshError = null;
    isOffline = _connectivityService.isOnline == false;
    _notifyIfAlive();

    try {
      final userId = await _authService.getCurrentUserId();
      if (userId == null || userId.isEmpty) {
        throw const AuthException(message: 'No pudimos identificar tu sesión.');
      }
      _userId = userId;
      final cached = _repository.getCachedForUser(userId);
      if (cached != null && cached.isNotEmpty) {
        activities = _forDisplay(cached);
        isLoading = false;
        _notifyIfAlive();
      }
      activities = _forDisplay(await _repository.getForUser(userId));
      isLoading = false;
      _notifyIfAlive();

      if (_connectivityService.isOnline != false) {
        await refresh();
      }
    } on Exception catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      _notifyIfAlive();
    }
  }

  Future<void> refresh() async {
    final userId = _userId;
    if (userId == null || _refreshInProgress) return;
    if (_connectivityService.isOnline == false) {
      isOffline = true;
      _notifyIfAlive();
      return;
    }

    _refreshInProgress = true;
    isRefreshing = true;
    refreshError = null;
    _notifyIfAlive();

    try {
      await _repository.refreshFromBackend(userId);
      activities = await _repository.getForUser(userId);
      refreshError = null;
    } on Exception catch (error) {
      refreshError = error.toString();
    } finally {
      _refreshInProgress = false;
      isRefreshing = false;
      _notifyIfAlive();
    }
  }

  Future<void> leaveActivity(JoinedActivityRecord enrollment) async {
    final activityId = enrollment.activity.id;
    if (!_leavingActivityIds.add(activityId)) return;
    _notifyIfAlive();
    try {
      await _leaveActivity(enrollment);
    } finally {
      _leavingActivityIds.remove(activityId);
      _notifyIfAlive();
    }
  }

  Future<void> _leaveActivity(JoinedActivityRecord enrollment) async {
    final userId = _userId;
    if (userId == null) {
      throw const AuthException(message: 'No pudimos identificar tu sesión.');
    }

    final activityId = enrollment.activity.id;
    if (enrollment.isPendingLeave) return;

    final action = _newAction(
      userId: userId,
      activityId: activityId,
      type: PendingActionType.leaveActivity,
    );

    if (enrollment.isPendingJoin &&
        enrollment.syncStatus != JoinedSyncStatus.processing) {
      await _repository.enqueueLeave(action);
      await _reloadLocal();
      return;
    }

    if (_connectivityService.isOnline == true) {
      try {
        await _activityService.leave(activityId);
        await _repository.recordConfirmedLeave(
          userId: userId,
          activityId: activityId,
        );
        await _reloadLocal();
        return;
      } catch (error) {
        if (!_isRetryable(error)) rethrow;
      }
    }

    await _repository.enqueueLeave(action);
    await _reloadLocal();
    if (_connectivityService.isOnline == true) {
      unawaited(_syncService.syncPendingActions());
    }
  }

  Future<void> retryAction(JoinedActivityRecord enrollment) async {
    final userId = _userId;
    if (userId == null) return;

    final retried = await _repository.retryFailedAction(
      userId: userId,
      activityId: enrollment.activity.id,
    );
    if (!retried) return;
    await _reloadLocal();
    if (_connectivityService.isOnline == true) {
      await _syncService.syncPendingActions();
      await _reloadLocal();
    }
  }

  void togglePastActivities() {
    pastActivitiesExpanded = !pastActivitiesExpanded;
    _notifyIfAlive();
  }

  Future<void> _reloadLocal() async {
    final userId = _userId;
    if (userId == null) return;
    activities = _forDisplay(await _repository.getForUser(userId));
    await _syncCurrentUserPlansSafely();
    _notifyIfAlive();
  }

  Future<void> _syncCurrentUserPlansSafely() async {
    try {
      await _syncCurrentUserPlans();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'activity reminder synchronization',
        ),
      );
    }
  }

  void _onConnectivityChanged(bool online) {
    isOffline = !online;
    if (!online) activities = _forDisplay(activities);
    _notifyIfAlive();
    if (online) unawaited(_reconnect());
  }

  List<JoinedActivityRecord> _forDisplay(List<JoinedActivityRecord> records) {
    if (!isOffline) return records;
    return records
        .map(
          (record) => record.syncStatus == JoinedSyncStatus.processing
              ? record.copyWith(syncStatus: JoinedSyncStatus.pending)
              : record,
        )
        .toList(growable: false);
  }

  Future<void> _reconnect() async {
    await _syncService.syncPendingActions();
    await refresh();
  }

  void _onActionSynced(PendingAction action) {
    if (_userId == null || action.userId != _userId) return;
    unawaited(_reloadLocal());
  }

  PendingAction _newAction({
    required String userId,
    required String activityId,
    required PendingActionType type,
  }) {
    final now = _now().toUtc();
    return PendingAction(
      id: const Uuid().v4(),
      userId: userId,
      type: type,
      activityId: activityId,
      payload: const {},
      status: PendingActionStatus.pending,
      attempts: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  bool _isPast(JoinedActivityRecord item) {
    final end = DateTime.tryParse(item.activity.endTime);
    return end != null && !end.isAfter(_now());
  }

  bool _isRetryable(Object error) {
    if (error is SocketException ||
        error is http.ClientException ||
        error is TimeoutException) {
      return true;
    }

    final statusCode = switch (error) {
      ActivityException() => error.statusCode,
      AuthException() => error.statusCode,
      _ => null,
    };
    return statusCode == 408 ||
        statusCode == 429 ||
        (statusCode != null && statusCode >= 500);
  }

  void _notifyIfAlive() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_connectivitySubscription.cancel());
    unawaited(_syncSubscription.cancel());
    super.dispose();
  }
}
