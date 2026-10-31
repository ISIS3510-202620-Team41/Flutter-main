
import 'dart:async';

import 'package:http/http.dart' as http;

import '../analytics/analytics_facade.dart';
import '../analytics/analytics_feature_catalog.dart';
import '../database/local_database_facade.dart';
import '../models/pending_action.dart';
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
    AnalyticsFacade? analyticsFacade,
  })  : _connectivityService =
            connectivityService ?? ConnectivityService.instance,
        _injectedRepository = repository,
        _authService = authService ?? AuthService(),
        _analyticsFacade =
            analyticsFacade ?? AnalyticsFacade.instance;

  static final instance = PendingActionsSyncService();

  final ConnectivityService _connectivityService;
  final PendingActionsRepository? _injectedRepository;
  final AuthService _authService;
  final ActivityService? _activityService;
  final AnalyticsFacade _analyticsFacade;


  PendingActionsRepository? get _repository =>
      _injectedRepository ?? LocalDatabaseFacade.instance.pendingActions;

  ActivityService get _activities =>
      _activityService ?? ActivityService(authService: _authService);

  final StreamController<PendingAction> _syncedController =
      StreamController<PendingAction>.broadcast();

  Stream<PendingAction> get onActionSynced =>
      _syncedController.stream;

  StreamSubscription<bool>? _connectivitySubscription;

  bool _isSyncing = false; //Evitamos dupes de sync

  void start() {
    if (_connectivitySubscription != null) return;

    _connectivitySubscription =
        _connectivityService.onConnectivityChanged.listen(
      (isOnline) {
        if (isOnline && authSession.isAuthenticated == true) {
          unawaited(syncPendingActions());
        }
      },
    );
  }

  Future<void> syncPendingActions() async {
    if (_isSyncing) return;

    if (_connectivityService.isOnline != true) return;

    if (authSession.isAuthenticated != true) return;

    final repository = _repository;

    if (repository == null) return;

    // Bloqueamos nuevas sincronizaciones antes de cualquier await.
    _isSyncing = true;

    try {
      final userId = await _authService.getCurrentUserId();

      if (userId == null) return;

      // Recuperamos acciones que quedaron procesándose antes del cierre.
      await repository.recoverProcessing(userId);

      final actions = await repository.getPending(userId);

      for (final action in actions) {
        if (_connectivityService.isOnline != true) break;

        if (authSession.isAuthenticated != true) break;

        await repository.updateStatus(
          id: action.id,
          status: PendingActionStatus.processing,
          lastError: null,
        );

        try {
          await _processAction(action);

          // El backend aceptó la petición.
          await repository.delete(action.id);

          _syncedController.add(action);

          await _recordJoinAnalytics(action);
        } on SessionExpiredException catch (error) {
          // Se conserva para cuando el usuario vuelva a autenticarse.
          await repository.updateStatus(
            id: action.id,
            status: PendingActionStatus.pending,
            attempts: action.attempts + 1,
            lastError: error.message,
          );

          break;
        } catch (error) {
          final retryable = _isRetryableError(error);

          await repository.updateStatus(
            id: action.id,
            status: retryable
                ? PendingActionStatus.pending
                : PendingActionStatus.failed,
            attempts: action.attempts + 1,
            lastError: error.toString(),
          );

          if (retryable) break;
        }
      }
    } finally {
      // Liberamos el bloqueo incluso si ocurre una excepción.
      _isSyncing = false;
    }
  }

  Future<void> _processAction(PendingAction action) async {
    switch (action.type) {
      case PendingActionType.joinActivity:
        final recommendationId =
            action.payload['recommendationId'] as String?;

        final rawMinutes = action.payload['freeTimeMinutes'];

        final freeTimeMinutes = rawMinutes is num
            ? rawMinutes.toInt()
            : null;

        await _activities.join(
          action.activityId,
          recommendationId: recommendationId,
          freeTimeMinutes: freeTimeMinutes,
        );

        break;

      case PendingActionType.leaveActivity:
        throw UnsupportedError(
          'LEAVE_ACTIVITY synchronization is not implemented.',
        );
      case PendingActionType.createActivity:
        // Las actividades creadas sin conexión se sincronizan por su
        // propio flujo; esta cola todavía no las procesa.
        throw UnsupportedError(
          'CREATE_ACTIVITY synchronization is not implemented.',
            );
         }
  }

  bool _isRetryableError(Object error) {
    if (error is http.ClientException ||
        error is TimeoutException) {
      return true;
    }

    int? statusCode;

    if (error is ActivityException ||
        error is AuthException) {
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
    } catch (_) {
    }
  }

  Future<void> stop() async {
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }
}
