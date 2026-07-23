import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../config/app_constants.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(AppConstants.databaseName);
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
      CREATE TABLE ${AppConstants.pendingPointsTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lat REAL NOT NULL,
        lon REAL NOT NULL,
        recorded_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> insertPoint(double lat, double lon) async {
    final db = await instance.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert(AppConstants.pendingPointsTable, {'lat': lat, 'lon': lon, 'recorded_at': now});
  }

  Future<List<Map<String, dynamic>>> getPendingPoints() async {
    final db = await instance.database;
    return await db.query(AppConstants.pendingPointsTable, orderBy: 'recorded_at ASC');
  }
  
  Future<void> clearPendingPoints() async {
    final db = await instance.database;
    await db.delete(AppConstants.pendingPointsTable);
  }
}
