import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../repositories/activity_local_repository.dart';
import '../repositories/user_preferences_repository.dart';
import '../repositories/pending_actions_repository.dart';

class LocalDatabaseService {
  LocalDatabaseService._({required this.database, required Database connection,}) {
    activities = ActivityLocalRepository(connection);
    preferences = UserPreferencesRepository(connection);
    pendingActions = PendingActionsRepository(connection);
  }

  final AppDatabase database;

  late final ActivityLocalRepository activities;
  late final UserPreferencesRepository preferences;
  late final PendingActionsRepository pendingActions;

  static Future<LocalDatabaseService> open({AppDatabase? database,}) async {
    final appDatabase = database ?? AppDatabase();

    final connection = await appDatabase.database;

    return LocalDatabaseService._(
      database: appDatabase,
      connection: connection,
    );
  }

  Future<void> close() async {
    await activities.dispose();
    await database.close();
  }
}
