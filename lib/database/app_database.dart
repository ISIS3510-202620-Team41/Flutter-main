import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;

class AppDatabase {
  AppDatabase({sqflite.DatabaseFactory? databaseFactory, this._databasePath})
    : _databaseFactory = databaseFactory ?? sqflite.databaseFactory;

  static const String databaseName = 'llamalla.db';
  static const int databaseVersion = 4;

  static const _createPendingAvatarUploadsTable = '''
    CREATE TABLE IF NOT EXISTS pending_avatar_uploads (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL UNIQUE,
      local_path TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK(status IN ('PENDING', 'PROCESSING', 'FAILED')),
      attempt_count INTEGER NOT NULL DEFAULT 0,
      last_error TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''';

  static const _createPendingActionsTable = '''
    CREATE TABLE pending_actions (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      action_type TEXT NOT NULL
        CHECK(action_type IN (
          'JOIN_ACTIVITY',
          'LEAVE_ACTIVITY',
          'CREATE_ACTIVITY'
        )),
      activity_id TEXT NOT NULL,
      payload_json TEXT NOT NULL DEFAULT '{}',
      status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK(status IN (
          'PENDING',
          'PROCESSING',
          'FAILED',
          'COMPLETED'
        )),
      attempts INTEGER NOT NULL DEFAULT 0,
      last_error TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''';

  static const _createPendingActionsIndex = '''
    CREATE INDEX idx_pending_actions_user_status
    ON pending_actions(user_id, status, created_at)
  ''';

  static const _createJoinedActivitiesTable = '''
    CREATE TABLE joined_activities (
      user_id TEXT NOT NULL,
      activity_id TEXT NOT NULL,
      enrollment_status TEXT NOT NULL
        CHECK(enrollment_status IN (
          'CONFIRMED',
          'PENDING_JOIN',
          'PENDING_LEAVE'
        )),
      sync_status TEXT NOT NULL
        CHECK(sync_status IN (
          'SYNCED',
          'PENDING',
          'PROCESSING',
          'FAILED'
        )),
      enrollment_id TEXT,
      joined_at TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      synced_at TEXT,
      last_error TEXT,
      PRIMARY KEY(user_id, activity_id)
    )
  ''';

  static const _createJoinedActivitiesIndex = '''
    CREATE INDEX idx_joined_activities_user_status
    ON joined_activities(user_id, enrollment_status, updated_at)
  ''';

  static const _backfillJoinedActivitiesFromPendingActions = '''
    INSERT OR REPLACE INTO joined_activities (
      user_id,
      activity_id,
      enrollment_status,
      sync_status,
      enrollment_id,
      joined_at,
      created_at,
      updated_at,
      synced_at,
      last_error
    )
    SELECT
      user_id,
      activity_id,
      CASE action_type
        WHEN 'JOIN_ACTIVITY' THEN 'PENDING_JOIN'
        ELSE 'PENDING_LEAVE'
      END,
      CASE status
        WHEN 'PROCESSING' THEN 'PROCESSING'
        WHEN 'FAILED' THEN 'FAILED'
        ELSE 'PENDING'
      END,
      NULL,
      NULL,
      created_at,
      updated_at,
      NULL,
      last_error
    FROM pending_actions
    WHERE action_type IN ('JOIN_ACTIVITY', 'LEAVE_ACTIVITY')
      AND status != 'COMPLETED'
    ORDER BY created_at ASC, updated_at ASC
  ''';

  final sqflite.DatabaseFactory _databaseFactory;
  final String? _databasePath;

  sqflite.Database? _database;

  /// Returns the opened database or initializes it on first access.
  Future<sqflite.Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final path =
        _databasePath ?? p.join(await sqflite.getDatabasesPath(), databaseName);

    _database = await _databaseFactory.openDatabase(
      path,
      options: sqflite.OpenDatabaseOptions(
        version: databaseVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );

    return _database!;
  }

  Future<void> _onConfigure(sqflite.Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(sqflite.Database db, int version) async {
    await db.execute('''
      CREATE TABLE activities (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        category TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        location_name TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        image_url TEXT,
        local_image_path TEXT,
        price TEXT,
        capacity INTEGER,
        about_location TEXT,
        participants INTEGER NOT NULL DEFAULT 0,
        distance_km REAL,
        cached_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_activities_start_time
      ON activities(start_time)
    ''');

    await db.execute('''
      CREATE INDEX idx_activities_category
      ON activities(category)
    ''');

    await db.execute('''
      CREATE TABLE user_preferences (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        category TEXT NOT NULL,
        score REAL NOT NULL,
        cached_at TEXT NOT NULL,
        UNIQUE(user_id, category)
      )
    ''');

    await db.execute(_createPendingActionsTable);
    await db.execute(_createPendingActionsIndex);
    await db.execute(_createJoinedActivitiesTable);
    await db.execute(_createJoinedActivitiesIndex);
    await db.execute(_createPendingAvatarUploadsTable);
  }

  /// Actualiza incrementalmente los schemas
  Future<void> _onUpgrade(
    sqflite.Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute('''
        ALTER TABLE activities
        ADD COLUMN local_image_path TEXT
      ''');
      // v2: pending_actions accepts CREATE_ACTIVITY. SQLite cannot change a
      // CHECK constraint, so the table is rebuilt and its rows are copied.
      await db.execute(
        'ALTER TABLE pending_actions RENAME TO pending_actions_old',
      );
      await db.execute(_createPendingActionsTable);
      await db.execute(
        'INSERT INTO pending_actions SELECT * FROM pending_actions_old',
      );
      // Dropping the old table also drops its old index, so the index name
      // is free to be created again.
      await db.execute('DROP TABLE pending_actions_old');
      await db.execute(_createPendingActionsIndex);
    }

    if (oldVersion < 3) {
      await db.execute(_createJoinedActivitiesTable);
      await db.execute(_createJoinedActivitiesIndex);
      await db.execute(_backfillJoinedActivitiesFromPendingActions);
    }

    if (oldVersion < 4) {
      await db.execute(_createPendingAvatarUploadsTable);
    }
  }

  Future<void> close() async {
    final db = _database;

    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
