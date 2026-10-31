
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/activity.dart';
import '../models/activity_draft.dart';
import '../services/activity_service.dart';

class CreateResult {
  const CreateResult(this.activity, {this.savedOffline = false});

  final Activity activity;
  final bool savedOffline;
}

/// Primero intenta guardar la actividad en el servidor, si no hay conexión, guarda el borrador localmente para que el usuario no pierda la actividad
class ActivityRepository {
  ActivityRepository({ActivityService? service})
      : _service = service ?? ActivityService();

  static const _pendingKey = 'pending_activity_drafts';
  static const _timeout = Duration(seconds: 10);

  final ActivityService _service;

  Future<CreateResult> create(ActivityDraft draft, {String? source}) async {
    try {
      final activity = await _service
          .createActivity(draft.toRequestJson(), source: source)
          .timeout(_timeout);
      unawaited(syncPending()); // Hay conexión, sincroniza los borradores anteriores.
      return CreateResult(activity);
    } catch (error) {
      if (!_isNetworkError(error)) rethrow;
      await _save(draft);
      return CreateResult(draft.toActivity(), savedOffline: true);
    }
  }

  Future<List<ActivityDraft>> pending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) =>
        ActivityDraft.fromStorageJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Envía los borradores guardados al servidor, devuelve la cantidad de actividades creadas y la tarea #32 llamará  vuelva la conexión
  Future<int> syncPending() async {
    var synced = 0;
    for (final draft in await pending()) {
      try {
        await _service
            .createActivity(draft.toRequestJson())
            .timeout(_timeout);
        await _remove(draft.clientId);
        synced++;
      } catch (error) {
        final rejected = error is ActivityException &&
            (error.statusCode ?? 500) < 500;
        if (rejected) {
          await _remove(draft.clientId); // El servidor nunca aceptará este borrador.
        } else {
          break; // Problema de conexión o del servidor; se intentará más tarde.
        }
      }
    }
    return synced;
  }

  // Comprueba si el error se debe a un problema de conexión.
  bool _isNetworkError(Object error) =>
      error is SocketException ||
          error is TimeoutException ||
          error is http.ClientException;

  // Guarda un borrador de actividad en el almacenamiento local.
  Future<void> _save(ActivityDraft draft) async {
    final drafts = await pending();
    drafts.add(draft);
    await _write(drafts);
  }

  // Elimina un borrador usando su identificador único.
  Future<void> _remove(String clientId) async {
    final drafts = await pending();
    drafts.removeWhere((d) => d.clientId == clientId);
    await _write(drafts);
  }

  // Actualiza la lista de borradores guardados localmente.
  Future<void> _write(List<ActivityDraft> drafts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _pendingKey,
      jsonEncode(drafts.map((d) => d.toStorageJson()).toList()),
    );
  }
}