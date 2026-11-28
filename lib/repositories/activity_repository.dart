import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../analytics/analytics_facade.dart';
import '../database/local_database_facade.dart';
import '../models/activity.dart';
import '../models/activity_draft.dart';
import '../models/plan_creation_context.dart';
import '../models/pending_action.dart';
import '../services/activity_service.dart';
import '../services/session_user.dart';
import 'activity_local_repository.dart';
import 'pending_actions_repository.dart';

class CreateResult {
  const CreateResult(this.activity, {this.savedOffline = false});

  final Activity activity;
  final bool savedOffline;
}

// Crea actividades online o las guarda localmente
class ActivityRepository {
  static const _creationSourceKey = '_creationSource';

  ActivityRepository({
    ActivityService? service,
    ActivityLocalRepository? localRepository,
    PendingActionsRepository? pendingActions,
    AnalyticsFacade? analyticsFacade,
    Future<bool> Function()? isOnline,
    Future<String?> Function()? userId,
  }) : _service = service ?? ActivityService(),
       _injectedLocal = localRepository,
       _injectedPending = pendingActions,
       _analyticsFacade = analyticsFacade ?? AnalyticsFacade.instance,
       _isOnline = isOnline ?? _defaultIsOnline,
       _userId = userId ?? currentUserId;

  static const _timeout = Duration(seconds: 10);

  // Evita sincronizaciones simultáneas
  static bool _syncing = false;

  final ActivityService _service;
  final ActivityLocalRepository? _injectedLocal;
  final PendingActionsRepository? _injectedPending;
  final AnalyticsFacade _analyticsFacade;
  final Future<bool> Function() _isOnline;
  final Future<String?> Function() _userId;

  ActivityLocalRepository? get _local =>
      _injectedLocal ?? LocalDatabaseFacade.instance.activities;
  PendingActionsRepository? get _pending =>
      _injectedPending ?? LocalDatabaseFacade.instance.pendingActions;

  static Future<bool> _defaultIsOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }

  Future<CreateResult> create(ActivityDraft draft, {String? source}) async {
    final context = _contextFor(draft);
    final freeTimeMinutes = context.freeTimeMinutes;
    final hasType5Context = freeTimeMinutes != null && freeTimeMinutes >= 0;
    final attemptId = hasType5Context
        ? draft.attemptId ?? const Uuid().v4()
        : null;
    final requestBody = draft.toRequestJson(attemptIdOverride: attemptId);
    if (attemptId == null) {
      requestBody.remove('attemptId');
    }

    if (attemptId != null) {
      await _publishCreationAttempt(attemptId, context);
    }

    // Comprueba la conexión antes de crear
    if (await _isOnline()) {
      try {
        final activity = await _service
            .createActivity(requestBody, source: source)
            .timeout(_timeout);

        await _joinCreator(activity.id);
        unawaited(syncPending());
        return CreateResult(activity);
      } catch (error) {
        if (!_isNetworkError(error)) rethrow;
      }
    }
    return _saveOffline(
      draft,
      requestBody: requestBody,
      context: context,
      source: source,
    );
  }

  Future<CreateResult> _saveOffline(
    ActivityDraft draft, {
    required Map<String, dynamic> requestBody,
    required PlanCreationContext context,
    String? source,
  }) async {
    final local = _local;
    final pending = _pending;
    final userId = await _userId();
    if (local == null || pending == null || userId == null) {
      throw const ActivityException(
        'No pudimos guardar la actividad en tu dispositivo.',
      );
    }

    final localId = '$localActivityIdPrefix${draft.clientId}';
    final record = draft.toRecord(localId);
    await local.insert(record);

    final now = DateTime.now().toUtc();
    final payload = {
      ...requestBody,
      '_planCreationContext': context.toMap(),
    };
    if (source != null) {
      payload[_creationSourceKey] = source;
    }

    try {
      await pending.enqueue(
        PendingAction(
          id: draft.clientId,
          userId: userId,
          type: PendingActionType.createActivity,
          activityId: localId,
          payload: payload,
          status: PendingActionStatus.pending,
          attempts: 0,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } catch (_) {
      await local.delete(localId);
      rethrow;
    }

    return CreateResult(record.toActivity(), savedOffline: true);
  }

  // Envía en orden las tareas CREATE_ACTIVITY que están en la cola, devuelve cuántas se han sincronizado
  Future<int> syncPending() async {
    if (_syncing) return 0;
    _syncing = true;
    try {
      final pending = _pending;
      final local = _local;
      final userId = await _userId();
      if (pending == null || local == null || userId == null) return 0;

      // estado PROCESSING: vuelve a colocarlas en la cola.
      for (final action in await pending.getAllByUser(userId)) {
        if (action.status == PendingActionStatus.processing) {
          await pending.updateStatus(
            id: action.id,
            status: PendingActionStatus.pending,
          );
        }
      }

      var synced = 0;
      for (final action in await pending.getPending(userId)) {
        if (action.type != PendingActionType.createActivity) continue;

        await pending.updateStatus(
          id: action.id,
          status: PendingActionStatus.processing,
          attempts: action.attempts + 1,
        );
        try {
          final requestBody = Map<String, dynamic>.from(action.payload)
            ..remove('_planCreationContext');
          final context = action.payload['_planCreationContext'];
          final freeTimeMinutes = context is Map
              ? context['freeTimeMinutes']
              : null;
          if (freeTimeMinutes is! num || freeTimeMinutes < 0) {
            requestBody.remove('attemptId');
          }
          final source = requestBody.remove(_creationSourceKey) as String?;
          final created = await _service
              .createActivity(requestBody, source: source)
              .timeout(_timeout);
          await _joinCreator(created.id);
          await local.delete(action.activityId);
          await pending.delete(action.id);
          synced++;
        } catch (error) {
          final rejected =
              error is ActivityException &&
              (error.statusCode ?? 0) >= 400 &&
              (error.statusCode ?? 0) < 500 &&
              error.statusCode != 401 &&
              error.statusCode != 403;
          await pending.updateStatus(
            id: action.id,
            status: rejected
                ? PendingActionStatus.failed
                : PendingActionStatus.pending,
            lastError: '$error',
            attempts: action.attempts + 1,
          );
          if (!rejected) break;
        }
      }
      return synced;
    } finally {
      _syncing = false;
    }
  }

  PlanCreationContext _contextFor(ActivityDraft draft) {
    return draft.planCreationContext ??
        PlanCreationContext(
          preferences: [draft.category],
          freeTimeMinutes: draft.planCreationContext?.freeTimeMinutes,
          locationName: draft.locationName,
          latitude: draft.latitude,
          longitude: draft.longitude,
          availableFriendsCount: draft.friends.length,
          selectedAvailableFriendsCount: draft.friends.length,
        );
  }

  Future<void> _publishCreationAttempt(
    String attemptId,
    PlanCreationContext context,
  ) async {
    final freeTimeMinutes = context.freeTimeMinutes;
    if (freeTimeMinutes == null || freeTimeMinutes < 0) return;

    try {
      await _analyticsFacade.trackPlanCreationAttempted(
        attemptId: attemptId,
        context: context,
      );
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'activity creation analytics',
        ),
      );
    }
  }

  // El backend no inscribe al creador solo (responde participants: 0)
  Future<void> _joinCreator(String? activityId) async {
    if (activityId == null) return;
    try {
      await _service.join(activityId).timeout(_timeout);
    } catch (_) {
      // Puede ser un 409 (ya inscrito) o un fallo de red.
    }
  }

  bool _isNetworkError(Object error) =>
      error is SocketException ||
      error is TimeoutException ||
      error is http.ClientException;
}
