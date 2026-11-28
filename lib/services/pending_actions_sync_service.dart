import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../analytics/analytics_facade.dart';
import '../analytics/analytics_feature_catalog.dart';
import '../database/local_database_facade.dart';
import '../models/pending_action.dart';
import '../repositories/joined_activities_repository.dart';
import '../repositories/pending_actions_repository.dart';

import 'activity_service.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';

class PendingActionsSyncService {
  PendingActionsSyncService({
    ConnectivityService? connectivityService,
    PendingActionsRepository? repository,
    AuthService? authService,
    this._activityService,
    JoinedActivitiesRepository? joinedActivitiesRepository,
    AnalyticsFacade? analyticsFacade,
  }) : _connectivityService =
           connectivityService ?? ConnectivityService.instance,
       _injectedRepository = repository,
       _injectedJoinedActivitiesRepository = joinedActivitiesRepository,
       _authService = authService ?? AuthService(),
       _analyticsFacade = analyticsFacade ?? AnalyticsFacade.instance;

  static final instance = PendingActionsSyncService();

  final ConnectivityService _connectivityService;
  final PendingActionsRepository? _injectedRepository;
  final JoinedActivitiesRepository? _injectedJoinedActivitiesRepository;
  final AuthService _authService;
  final ActivityService? _activityService;
  final AnalyticsFacade _analyticsFacade;

  PendingActionsRepository? get _repository =>
      _injectedRepository ?? LocalDatabaseFacade.instance.pendingActions;

  JoinedActivitiesRepository? get _joinedRepository =>
      _injectedJoinedActivitiesRepository ??
      LocalDatabaseFacade.instance.joinedActivities;

  ActivityService get _activities =>
      _activityService ?? ActivityService(authService: _authService);

  final StreamController<PendingAction> _syncedController =
      StreamController<PendingAction>.broadcast();

  Stream<PendingAction> get onActionSynced => _syncedController.stream;

  StreamSubscription<bool>? _connectivitySubscription;

  bool _isSyncing = false; //Evitamos dupes de sync
  bool _syncRequested = false;

  void start() {
    if (_connectivitySubscription != null) return;

    _connectivitySubscription = _connectivityService.onConnectivityChanged
        .listen((isOnline) {
          if (isOnline && authSession.isAuthenticated == true) {
            if (_isSyncing) {
              _syncRequested = true;
              return;
            }
            unawaited(syncPendingActions());
          }
        });
  }

  Future<void> syncPendingActions() async {
    if (_isSyncing) return;

    if (_connectivityService.isOnline != true) return;

    if (authSession.isAuthenticated != true) return;

    final repository = _repository;

    if (repository == null) return;
    final joinedRepository = _joinedRepository;

    // Bloqueamos nuevas sincronizaciones antes de cualquier await.
    _isSyncing = true;

    try {
      final userId = await _authService.getCurrentUserId();

      if (userId == null) return;

      // Recuperamos acciones que quedaron procesándose antes del cierre.
      await repository.recoverProcessing(userId);

      while (true) {
        if (_connectivityService.isOnline != true ||
            authSession.isAuthenticated != true) {
          break;
        }

        final actions = await repository.getPending(userId);
        if (actions.isEmpty) break;
        var stopAfterBatch = false;

        for (final action in actions) {
          if (_connectivityService.isOnline != true ||
              authSession.isAuthenticated != true) {
            stopAfterBatch = true;
            break;
          }

          if (joinedRepository != null &&
              (action.type == PendingActionType.joinActivity ||
                  action.type == PendingActionType.leaveActivity)) {
            await joinedRepository.updateActionStatus(
              action: action,
              status: PendingActionStatus.processing,
              lastError: null,
            );
          } else {
            await repository.updateStatus(
              id: action.id,
              status: PendingActionStatus.processing,
              lastError: null,
            );
          }

          try {
            await _processAction(action);

            // El backend aceptó la petición.
            if (joinedRepository != null &&
                (action.type == PendingActionType.joinActivity ||
                    action.type == PendingActionType.leaveActivity)) {
              await joinedRepository.completeAction(action);
            } else {
              await repository.delete(action.id);
            }

            _syncedController.add(action);

            await _recordJoinAnalytics(action);
          } on SessionExpiredException catch (error) {
            // Se conserva para cuando el usuario vuelva a autenticarse.
            await _updateFailedAction(
              repository: repository,
              joinedRepository: joinedRepository,
              action: action,
              status: PendingActionStatus.pending,
              attempts: action.attempts + 1,
              lastError: error.message,
            );
            stopAfterBatch = true;
            break;
          } catch (error) {
            final retryable = _isRetryableError(error);

            await _updateFailedAction(
              repository: repository,
              joinedRepository: joinedRepository,
              action: action,
              status: retryable
                  ? PendingActionStatus.pending
                  : PendingActionStatus.failed,
              attempts: action.attempts + 1,
              lastError: error.toString(),
            );

            if (retryable) {
              stopAfterBatch = true;
              break;
            }
          }
        }

        if (stopAfterBatch) break;
      }
    } finally {
      // Liberamos el bloqueo incluso si ocurre una excepción.
      _isSyncing = false;
      final retryRequested = _syncRequested;
      _syncRequested = false;
      if (retryRequested &&
          _connectivityService.isOnline == true &&
          authSession.isAuthenticated == true) {
        await syncPendingActions();
      }
    }
  }

  Future<void> _processAction(PendingAction action) async {
    switch (action.type) {
      case PendingActionType.joinActivity:
        final recommendationId = action.payload['recommendationId'] as String?;

        final rawMinutes = action.payload['freeTimeMinutes'];

        final freeTimeMinutes = rawMinutes is num ? rawMinutes.toInt() : null;

        try {
          await _activities.join(
            action.activityId,
            recommendationId: recommendationId,
            freeTimeMinutes: freeTimeMinutes,
          );
        } on ActivityException catch (error) {
          if (error.statusCode != 409) rethrow;
        }

        break;

      case PendingActionType.leaveActivity:
        await _activities.leave(action.activityId);
        break;
      case PendingActionType.createActivity:
        // Las actividades creadas sin conexión se sincronizan por su
        // propio flujo; esta cola todavía no las procesa.
        throw UnsupportedError(
          'CREATE_ACTIVITY synchronization is not implemented.',
        );
    }
  }

  Future<void> _updateFailedAction({
    required PendingActionsRepository repository,
    required JoinedActivitiesRepository? joinedRepository,
    required PendingAction action,
    required PendingActionStatus status,
    required int attempts,
    required String lastError,
  }) async {
    if (joinedRepository != null &&
        (action.type == PendingActionType.joinActivity ||
            action.type == PendingActionType.leaveActivity)) {
      await joinedRepository.updateActionStatus(
        action: action,
        status: status,
        attempts: attempts,
        lastError: lastError,
      );
      return;
    }

    await repository.updateStatus(
      id: action.id,
      status: status,
      attempts: attempts,
      lastError: lastError,
    );
  }

  bool _isRetryableError(Object error) {
    if (error is http.ClientException ||
        error is SocketException ||
        error is HandshakeException ||
        error is TimeoutException) {
      return true;
    }

    int? statusCode;

    if (error is ActivityException || error is AuthException) {
      statusCode = error is ActivityException
          ? error.statusCode
          : (error as AuthException).statusCode;
    }

    return statusCode == 408 ||
        statusCode == 429 ||
        (statusCode != null && statusCode >= 500);
  }

  Future<void> _recordJoinAnalytics(PendingAction action) async {
    if (action.type != PendingActionType.joinActivity) return;

    try {
      await _analyticsFacade.trackFeatureUsed(
        feature: AnalyticsFeatureCatalog.activityJoining,
        action: AnalyticsFeatureCatalog.joinRecommendedActivityAction,
        screen: AnalyticsFeatureCatalog.activityJoiningScreen,
      );
    } catch (_) {}
  }

  Future<void> stop() async {
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }
}
