import '../services/local_database_service.dart';
import '../repositories/activity_local_repository.dart';
import '../repositories/user_preferences_repository.dart';
import '../repositories/pending_actions_repository.dart';

class LocalDatabaseFacade {
  LocalDatabaseFacade._();

  static final instance = LocalDatabaseFacade._();

  LocalDatabaseService? _databaseService;
  Future<void>? _initialization;

  Future<void> initialize() {
    return _initialization ??= _initializeDatabase();
  }

  Future<void> _initializeDatabase() async {
    _databaseService = await LocalDatabaseService.open();
  }

  ActivityLocalRepository? get activities =>_databaseService?.activities;

  UserPreferencesRepository? get preferences =>_databaseService?.preferences;

  PendingActionsRepository? get pendingActions =>_databaseService?.pendingActions;

  Future<void> close() async {
    await _initialization;

    final database = _databaseService;
    _databaseService = null;
    _initialization = null;

    await database?.close();
  }
}