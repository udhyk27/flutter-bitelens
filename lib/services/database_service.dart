import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'bitelens.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE analysis_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            image_path TEXT NOT NULL,
            food_name TEXT,
            calories TEXT,
            result TEXT NOT NULL,
            created_at TEXT NOT NULL,
            is_favorite INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE weight_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            weight REAL NOT NULL,
            logged_at TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS weight_log (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              weight REAL NOT NULL,
              logged_at TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE analysis_history ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0',
          );
        }
      },
    );
  }

  // ─── analysis_history ────────────────────────────────────

  Future<int> insertAnalysis({
    required String imagePath,
    required String result,
  }) async {
    final db = await database;
    return await db.insert('analysis_history', {
      'image_path': imagePath,
      'result': result,
      'created_at': DateTime.now().toIso8601String(),
      'is_favorite': 0,
    });
  }

  /// 전체 기록 조회 (기존 코드 호환용)
  Future<List<Map<String, dynamic>>> getAnalysisHistory() async {
    final db = await database;
    return await db.query('analysis_history', orderBy: 'created_at DESC');
  }

  /// 페이지네이션 조회
  Future<List<Map<String, dynamic>>> getAnalysisHistoryPaged({
    int limit = 20,
    int offset = 0,
    bool favoritesOnly = false,
  }) async {
    final db = await database;
    return await db.query(
      'analysis_history',
      where: favoritesOnly ? 'is_favorite = 1' : null,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
  }

  /// 전체 기록 수 조회
  Future<int> getAnalysisCount({bool favoritesOnly = false}) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM analysis_history'
      '${favoritesOnly ? " WHERE is_favorite = 1" : ""}',
    );
    return (result.first['c'] as int?) ?? 0;
  }

  /// 즐겨찾기 토글
  Future<void> toggleFavorite(int id, bool isFavorite) async {
    final db = await database;
    await db.update(
      'analysis_history',
      {'is_favorite': isFavorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 최근 7일치 기록 조회 (주간 차트용)
  Future<List<Map<String, dynamic>>> getWeeklyHistory() async {
    final db = await database;
    final start = DateTime.now().subtract(const Duration(days: 6));
    final startStr =
        DateTime(start.year, start.month, start.day).toIso8601String();
    return await db.query(
      'analysis_history',
      where: 'created_at >= ?',
      whereArgs: [startStr],
      orderBy: 'created_at ASC',
    );
  }

  Future<void> deleteAnalysis(int id) async {
    final db = await database;
    await db.delete('analysis_history', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('analysis_history');
  }

  // ─── weight_log ──────────────────────────────────────────

  Future<int> insertWeight(double weight) async {
    final db = await database;
    return await db.insert('weight_log', {
      'weight': weight,
      'logged_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getWeightLog() async {
    final db = await database;
    return await db.query('weight_log', orderBy: 'logged_at ASC');
  }

  Future<void> deleteWeight(int id) async {
    final db = await database;
    await db.delete('weight_log', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearWeightLog() async {
    final db = await database;
    await db.delete('weight_log');
  }
}
