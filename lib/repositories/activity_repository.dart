import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import '../database/local_database_facade.dart';
import '../models/activity.dart';
import '../models/activity_draft.dart';
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
  ActivityRepository({
    ActivityService? service,
    ActivityLocalRepository? localRepository,
    PendingActionsRepository? pendingActions,
    Future<bool> Function()? isOnline,
    Future<String?> Function()? userId,
  })  : _service = service ?? ActivityService(),
        _injectedLocal = localRepository,
        _injectedPending = pendingActions,
        _isOnline = isOnline ?? _defaultIsOnline,
        _userId = userId ?? currentUserId;

  static const _timeout = Duration(seconds: 10);

  // Evita sincronizaciones simultáneas
  static bool _syncing = false;

  final ActivityService _service;
  final ActivityLocalRepository? _injectedLocal;
  final PendingActionsRepository? _injectedPending;
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
    // Comprueba la conexión antes de crear
    if (await _isOnline()) {
      try {
        final activity = await _service
            .createActivity(draft.toRequestJson(), source: source)
            .timeout(_timeout);
        unawaited(syncPending());
        return CreateResult(activity);
      } catch (error) {
        if (!_isNetworkError(error)) rethrow;
      }
    }
    return _saveOffline(draft);
  }

  Future<CreateResult> _saveOffline(ActivityDraft draft) async {
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
    try {
      await pending.enqueue(PendingAction(
        id: draft.clientId,
        userId: userId,
        type: PendingActionType.createActivity,
        activityId: localId,
        payload: draft.toRequestJson(),
        status: PendingActionStatus.pending,
        attempts: 0,
        createdAt: now,
        updatedAt: now,
      ));
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
          await _service.createActivity(action.payload).timeout(_timeout);
          await local.delete(action.activityId);
          await pending.delete(action.id);
          synced++;
        } catch (error) {
          final rejected = error is ActivityException &&
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

  bool _isNetworkError(Object error) =>
      error is SocketException ||
          error is TimeoutException ||
          error is http.ClientException;
}