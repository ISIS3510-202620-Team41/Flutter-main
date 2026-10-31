import 'dart:async';

import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../models/activity.dart';
import '../models/profile_models.dart';
import '../services/profile_service.dart';
import '../services/schedule_service.dart';
import '../services/activity_service.dart';
import '../services/location_service.dart';
import '../analytics/analytics_feature_catalog.dart';
import '../analytics/analytics_facade.dart';
import '../database/local_database_facade.dart';
import '../models/pending_action.dart';
import '../repositories/pending_actions_repository.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../services/pending_actions_sync_service.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    ProfileService? profileService,
    ScheduleService? scheduleService,
    ActivityService? activityService,
    LocationService? locationService,
    DateTime Function()? now,
    AnalyticsFacade? analyticsFacade,
    PendingActionsRepository? pendingActionsRepository,
    ConnectivityService? connectivityService,
    AuthService? authService,
    PendingActionsSyncService? syncService,
  })  : _profileService = profileService ?? ProfileService(),
        _scheduleService = scheduleService ?? ScheduleService(),
        _activityService = activityService ?? ActivityService(),
        _locationService = locationService ?? LocationService(),
        _now = now ?? DateTime.now,
        _analyticsFacade = analyticsFacade ?? AnalyticsFacade.instance,
        _pendingActionsRepository = pendingActionsRepository ?? LocalDatabaseFacade.instance.pendingActions,
        _connectivityService = connectivityService ?? ConnectivityService.instance,
        _authService = authService ?? AuthService(),
        _syncService = syncService ?? PendingActionsSyncService.instance { _syncSubscription = _syncService.onActionSynced.listen(_onActionSynced);}

  final ProfileService _profileService;
  final ScheduleService _scheduleService;
  final ActivityService _activityService;
  final LocationService _locationService;
  final AnalyticsFacade _analyticsFacade;
  final DateTime Function() _now;
  final PendingActionsRepository? _pendingActionsRepository;
  final ConnectivityService _connectivityService;
  final AuthService _authService;
  final PendingActionsSyncService _syncService;

  late final StreamSubscription<PendingAction> _syncSubscription;
  String? _currentUserId;

  final Set<String> _pendingActivityIds = {};
  final Set<String> _joiningActivityIds = {};

  bool wasLastJoinQueued = false;

  UserProfile? profile;
  FreeInterval? nextFreeInterval;
  bool isLoading = true;
  bool isLoadingRecommendations = true;
  String? errorMessage;

  List<Activity> recommendations = const [];
  String? recommendationId;
  int? recommendationFreeMinutes;
  String? recommendationsError;
  String? actionMessage;
  String networkQuality = 'unknown';

  String get greetingName {
    final name = profile?.name.trim() ?? '';
    return name.isEmpty ? 'allí' : name.split(RegExp(r'\s+')).first;
  }

  bool isActivityPending(String activityId) {
  return _pendingActivityIds.contains(activityId);
  }

  int get freeMinutes {
    final interval = nextFreeInterval;
    if (interval == null) return 0;
    return interval.end.difference(interval.start).inMinutes;
  }

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    recommendationsError = null;
    actionMessage = null;
    networkQuality = 'unknown';
    _networkProbe = Completer<void>();

    isLoadingRecommendations = recommendations.isEmpty;
    notifyListeners();

    // Cargamos las actividades que hay en cache
    final recommendationsFuture = _loadRecommendations();

    try {
      final probe = Stopwatch()..start();
      profile = await _profileService.getCurrentUser();
      _currentUserId = profile!.id;

      final date = _now();
      final gaps = await _scheduleService.getGaps(
        date: DateTime(date.year, date.month, date.day),
      );
      networkQuality = classifyNetworkQuality(probe.elapsed);

      final now = _now();
      final upcoming = gaps.free
          .where((gap) => gap.end.isAfter(now))
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));

      nextFreeInterval = upcoming.isEmpty ? null : upcoming.first;
    } on ProfileException catch (error) {
      errorMessage = error.message;
    } on ScheduleException catch (error) {
      errorMessage = error.message;
    } catch (_) {
      errorMessage = 'No pudimos cargar tu información. Intenta de nuevo.';
    } finally {
      if (!_networkProbe.isCompleted) _networkProbe.complete();
      isLoading = false;
      notifyListeners();
    }

    await _loadPendingActions();
    await recommendationsFuture;
  }

  Future<void> _loadRecommendations() async {
    recommendationsError = null;

    // Mostramos las actividades almacenadas en cache mientras obtenemos la ubicación y consultamos el backend.
    try {
      recommendations =
          await _activityService.getCachedActivities();

      recommendationId = null;
      recommendationFreeMinutes = null;

      isLoadingRecommendations = recommendations.isEmpty;
      notifyListeners();
    } catch (_) {}

    try {
      // obtenemos la ubicación del usuario
      final locationResult = await _locationService.current();

      final where = locationResult.location;

      // No hacemos consultas cercanas si no tenemos ubicacion
      if (where == null) {
        if (recommendations.isEmpty) {
          recommendationsError =
              _locationIssueMessage(locationResult.issue);
        }

        return;
      }

      recommendations =
          await _activityService.getCachedActivities(
        lat: where.lat,
        lon: where.lon,
      );

      isLoadingRecommendations = false;
      notifyListeners();
      
      // Esperamos la medición de red para enviar networkQuality al backend.
      await _networkProbe.future;

      // Consultamos al backend para obtener las recomendaciones más recientes
      final watch = Stopwatch()..start();
      final batch = await _activityService.getRecommendations(
        lat: where.lat,
        lon: where.lon,
        calculateDistanceLocally: true,
        networkQuality: networkQuality,
      );
      watch.stop();

      recommendations = batch.activities;
      recommendationId = batch.recommendationId;
      recommendationFreeMinutes = batch.freeMinutes;

      // BQ10: tiempo de carga de la pantalla de recomendaciones
      unawaited(_analyticsFacade.trackAppLoadingTime(
        loadType: 'screen',
        screen: 'recommendations',
        duration: watch.elapsed,
        networkQuality: networkQuality,
      ));
    } on ActivityException catch (error) {
      if (recommendations.isEmpty) {
        recommendationsError = error.message;
      }
    } catch (_) {
      if (recommendations.isEmpty) {
        recommendationsError =
            'No pudimos cargar las recomendaciones.';
      }
    } finally {
      isLoadingRecommendations = false;
      notifyListeners();
    }
   }
  

  Future<bool> choose(Activity activity) async {
    final id = activity.id;

    if (id == null || id.isEmpty) return false;

    actionMessage = null;
    wasLastJoinQueued = false;

    // Evitamos inscripciones duplicadas.
    if (_pendingActivityIds.contains(id)) {
      wasLastJoinQueued = true;
      actionMessage = 'Esta inscripción ya está pendiente.';
      notifyListeners();
      return true;
    }

    if (!_joiningActivityIds.add(id)) {
      return false;
    }

    try {
      try {
        await _analyticsFacade.trackFeatureUsed(
          feature: AnalyticsFeatureCatalog.activityRecommendations,
          action: AnalyticsFeatureCatalog.selectRecommendationAction,
          screen: AnalyticsFeatureCatalog.activityRecommendationsScreen,
        );
      } catch (_) {}

      // En caso de no conexion
      if (_connectivityService.isOnline == false) {
        return await _queueJoin(activity);
      }

      // Inscripcion normal
      try {
        await _activityService.join(
          id,
          recommendationId: recommendationId,
          freeTimeMinutes: recommendationFreeMinutes,
          networkQuality: networkQuality,
        );
      } catch (error) {
        if (_isRetryableJoinError(error)) {
          return await _queueJoin(activity);
        }

        rethrow;
      }

      // Inscripcion confirmada por el back
      try {
        await _analyticsFacade.trackFeatureUsed(
          feature: AnalyticsFeatureCatalog.activityJoining,
          action: AnalyticsFeatureCatalog.joinRecommendedActivityAction,
          screen: AnalyticsFeatureCatalog.activityJoiningScreen,
        );
      } catch (_) {}

      recommendations =
          recommendations.where((a) => a.id != id).toList();

      notifyListeners();

      return true;
    } on ActivityException catch (error) {
      actionMessage = error.message;
    } on AuthException catch (error) {
      actionMessage = error.message;
    } catch (_) {
      actionMessage = 'No pudimos unirnos a la actividad.';
    } finally {
      _joiningActivityIds.remove(id);
    }

    notifyListeners();

    return false;
  }

  Future<void> _loadPendingActions() async {
    try {
      final userId = _currentUserId ??
          await _authService.getCurrentUserId();

      if (userId == null) return;

      _currentUserId = userId;

      final repository = _pendingActionsRepository;

      if (repository == null) return;

      final actions = await repository.getPending(userId);

      _pendingActivityIds
        ..clear()
        ..addAll(
          actions
              .where(
                (action) =>
                    action.type == PendingActionType.joinActivity,
              )
              .map((action) => action.activityId),
        );

      notifyListeners();
    } catch (_) {
    }
  }

  Future<bool> _queueJoin(Activity activity) async {
    final activityId = activity.id;

    if (activityId == null) return false;

    final userId = _currentUserId ??
        await _authService.getCurrentUserId();

    if (userId == null) {
      actionMessage = 'No pudimos identificar tu sesión.';
      notifyListeners();
      return false;
    }

    final repository = _pendingActionsRepository;

    if (repository == null) {
      actionMessage = 'No pudimos acceder al almacenamiento local.';
      notifyListeners();
      return false;
    }

    final now = DateTime.now().toUtc();

    final action = PendingAction(
      id: const Uuid().v4(),
      userId: userId,
      type: PendingActionType.joinActivity,
      activityId: activityId,
      payload: {
        if (recommendationId != null)
          'recommendationId': recommendationId,
        if (recommendationFreeMinutes != null)
          'freeTimeMinutes': recommendationFreeMinutes,
      },
      status: PendingActionStatus.pending,
      attempts: 0,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await repository.enqueue(action);

      _currentUserId = userId;
      _pendingActivityIds.add(activityId);

      wasLastJoinQueued = true;

      actionMessage =
          'Inscripción guardada. Se sincronizará cuando vuelva la conexión.';

      notifyListeners();

      return true;
    } catch (_) {
      actionMessage =
          'No pudimos guardar tu inscripción localmente.';

      notifyListeners();

      return false;
    }
  }

  bool _isRetryableJoinError(Object error) {
    if (error is http.ClientException ||
        error is TimeoutException) {
      return true;
    }

    int? statusCode;

    if (error is ActivityException) {
      statusCode = error.statusCode;
    } else if (error is AuthException) {
      statusCode = error.statusCode;
    }

    return statusCode == 408 ||
        statusCode == 429 ||
        (statusCode != null && statusCode >= 500);
  }

  void _onActionSynced(PendingAction action) {
    if (action.type != PendingActionType.joinActivity) return;

    if (_currentUserId != null &&
        action.userId != _currentUserId) {
      return;
    }

    _pendingActivityIds.remove(action.activityId);

    recommendations = recommendations
        .where((activity) => activity.id != action.activityId)
        .toList();

    notifyListeners();
  }

  String _locationIssueMessage(LocationIssue? issue) {
    switch (issue) {
      case LocationIssue.serviceDisabled:
        return 'Activa la ubicación para encontrar actividades cercanas.';

      case LocationIssue.permissionDenied:
        return 'No tenemos permiso para acceder a tu ubicación.';

      case LocationIssue.permissionDeniedForever:
        return 'Habilita el permiso de ubicación desde los ajustes.';

      case LocationIssue.unavailable:
      case null:
        return 'No tenemos una ubicación disponible.';
    }
  }

  @override
  void dispose() {
    _syncSubscription.cancel();
    super.dispose();
  }
}

String formatClockTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

String classifyNetworkQuality(Duration elapsed) {
  final ms = elapsed.inMilliseconds;
  if (ms < 1500) return 'good';
  if (ms < 4000) return 'fair';
  return 'poor';
}
