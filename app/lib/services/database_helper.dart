import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('life_tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE pending_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lat REAL NOT NULL,
        lon REAL NOT NULL,
        recorded_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> insertPoint(double lat, double lon) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    await db.insert('pending_points', {'lat': lat, 'lon': lon, 'recorded_at': now});
  }

  Future<List<Map<String, dynamic>>> getPendingPoints() async {
    final db = await instance.database;
    return await db.query('pending_points', orderBy: 'recorded_at ASC');
  }
  
  Future<void> clearPendingPoints() async {
    final db = await instance.database;
    await db.delete('pending_points');
  }
}
