import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('life_tracker_v3.db'); // Changed filename to trigger migration
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sessions (
        id TEXT PRIMARY KEY,
        start_time INTEGER NOT NULL,
        end_time INTEGER,
        status TEXT NOT NULL,
        sync_state TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE gps_points (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        lat REAL NOT NULL,
        lon REAL NOT NULL,
        timestamp INTEGER NOT NULL,
        FOREIGN KEY(session_id) REFERENCES sessions(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE outbox_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_type TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0
      )
    ''');
    
    // Create indices
    await db.execute('CREATE INDEX idx_session_status ON sessions(status)');
    await db.execute('CREATE INDEX idx_session_sync ON sessions(sync_state)');
    await db.execute('CREATE INDEX idx_gps_session_time ON gps_points(session_id, timestamp)');

    // Rescue old points from v1 DB
    await _rescueOldPoints(db);
  }

  Future<void> _rescueOldPoints(Database newDb) async {
    try {
      final dbPath = await getDatabasesPath();
      final oldDbPath = join(dbPath, 'life_tracker.db');
      final oldDb = await openDatabase(oldDbPath, readOnly: true);
      
      // Check if old table exists
      final tables = await oldDb.query('sqlite_master', where: 'name = ?', whereArgs: ['pending_points']);
      if (tables.isNotEmpty) {
        final oldPoints = await oldDb.query('pending_points', orderBy: 'recorded_at ASC');
        if (oldPoints.isNotEmpty) {
          debugPrint('Rescuing \${oldPoints.length} points from old database...');
          
          // Create a dummy session for the rescued points
          final sessionId = const Uuid().v4();
          final startTime = DateTime.parse(oldPoints.first['recorded_at'] as String).millisecondsSinceEpoch;
          
          await newDb.insert('sessions', {
            'id': sessionId,
            'start_time': startTime,
            'end_time': startTime, // or just current time
            'status': 'ARCHIVED',
            'sync_state': 'DIRTY'
          });

          final batch = newDb.batch();
          for (var p in oldPoints) {
            final pointId = const Uuid().v4();
            final ts = DateTime.parse(p['recorded_at'] as String).millisecondsSinceEpoch;
            batch.insert('gps_points', {
              'id': pointId,
              'session_id': sessionId,
              'lat': p['lat'],
              'lon': p['lon'],
              'timestamp': ts,
            });
          }
          await batch.commit(noResult: true);
          debugPrint('Successfully rescued old points into session \$sessionId');
        }
      }
      await oldDb.close();
    } catch (e) {
      debugPrint('Error rescuing old points: \$e');
    }
  }

  // --- Helpers for Dart side --- //
  
  Future<String> createSession() async {
    final db = await instance.database;
    final sessionId = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await db.insert('sessions', {
      'id': sessionId,
      'start_time': now,
      'status': 'RECORDING',
      'sync_state': 'DIRTY'
    });
    return sessionId;
  }
  
  Future<Map<String, dynamic>?> getActiveSession() async {
    final db = await instance.database;
    final result = await db.query(
      'sessions', 
      where: 'status = ?', 
      whereArgs: ['RECORDING'],
      limit: 1
    );
    return result.isNotEmpty ? result.first : null;
  }
  
  Future<void> endActiveSession() async {
    final db = await instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'sessions',
      {'status': 'COMPLETED', 'end_time': now},
      where: 'status = ?',
      whereArgs: ['RECORDING']
    );
  }
  
  Future<List<Map<String, dynamic>>> getPointsForSession(String sessionId) async {
    final db = await instance.database;
    return await db.query(
      'gps_points',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC'
    );
  }
  
  Future<void> archiveAllCompletedSessions() async {
    final db = await instance.database;
    await db.update(
      'sessions',
      {'status': 'ARCHIVED'},
      where: 'status = ?',
      whereArgs: ['COMPLETED']
    );
  }
  
  Future<List<Map<String, dynamic>>> getArchivedPointsForToday() async {
    final db = await instance.database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    
    final result = await db.rawQuery('''
      SELECT p.* FROM gps_points p
      JOIN sessions s ON p.session_id = s.id
      WHERE s.status = 'ARCHIVED' AND s.start_time >= ?
      ORDER BY p.timestamp ASC
    ''', [startOfDay]);
    return result;
  }
  
  Future<List<Map<String, dynamic>>> getPointsForDate(String dateYYYYMMDD) async {
    final db = await instance.database;
    
    // Parse the date to get start and end timestamps
    final parts = dateYYYYMMDD.split('-');
    if (parts.length != 3) return [];
    
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);
    
    final startOfDay = DateTime(year, month, day).millisecondsSinceEpoch;
    final endOfDay = DateTime(year, month, day, 23, 59, 59, 999).millisecondsSinceEpoch;
    
    final result = await db.rawQuery('''
      SELECT p.* FROM gps_points p
      JOIN sessions s ON p.session_id = s.id
      WHERE p.timestamp >= ? AND p.timestamp <= ?
      ORDER BY p.timestamp ASC
    ''', [startOfDay, endOfDay]);
    
    return result;
  }
  
  // --- Phase 2: Sync Engine Helpers --- //
  
  Future<List<Map<String, dynamic>>> getDirtySessions() async {
    final db = await instance.database;
    return await db.query(
      'sessions',
      where: 'status = ? AND sync_state = ?',
      whereArgs: ['ARCHIVED', 'DIRTY'],
      orderBy: 'start_time ASC'
    );
  }
  
  Future<void> markSessionSynced(String sessionId) async {
    final db = await instance.database;
    await db.update(
      'sessions',
      {'sync_state': 'SYNCED'},
      where: 'id = ?',
      whereArgs: [sessionId]
    );
    
    // Once synced, we can safely delete the raw GPS points to save local space
    await db.delete(
      'gps_points',
      where: 'session_id = ?',
      whereArgs: [sessionId]
    );
  }
}
