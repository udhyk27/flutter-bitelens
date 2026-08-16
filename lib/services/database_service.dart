import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

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
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE analysis_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            image_path TEXT NOT NULL,
            food_name TEXT,
            calories TEXT,
            result TEXT NOT NULL,
            created_at TEXT NOT NULL,
            is_favorite INTEGER NOT NULL DEFAULT 0,
            meal TEXT
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
        if (oldVersion < 4) {
          await db.execute(
            'ALTER TABLE analysis_history ADD COLUMN meal TEXT',
          );
        }
      },
    );
  }

  // ─── 이미지 파일 영구 저장 ────────────────────────────────

  /// 히스토리 이미지 저장 디렉터리 (앱 전용 문서 영역)
  Future<Directory> _imageDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(join(base.path, 'history_images'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// 임시/캐시 경로의 이미지를 앱 전용 디렉터리로 복사해 영구 보관.
  /// 복사 실패 시 원본 경로를 그대로 반환(최소한 기록은 남김).
  Future<String> _persistImage(String srcPath) async {
    try {
      final src = File(srcPath);
      if (!await src.exists()) return srcPath;
      final dir = await _imageDir();
      final ext = extension(srcPath).isNotEmpty ? extension(srcPath) : '.jpg';
      final dest = join(dir.path, '${DateTime.now().microsecondsSinceEpoch}$ext');
      await src.copy(dest);
      return dest;
    } catch (_) {
      return srcPath;
    }
  }

  /// 우리가 복사한 히스토리 이미지에 한해 파일 삭제(사용자 갤러리 원본은 건드리지 않음).
  Future<void> _deleteImageFile(String? path) async {
    if (path == null) return;
    try {
      final dir = await _imageDir();
      if (!isWithin(dir.path, path)) return;
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  // ─── analysis_history ────────────────────────────────────

  Future<int> insertAnalysis({
    required String imagePath,
    required String result,
    String? meal,
  }) async {
    final db = await database;
    final persistedPath = await _persistImage(imagePath);
    return await db.insert('analysis_history', {
      'image_path': persistedPath,
      'result': result,
      'created_at': DateTime.now().toIso8601String(),
      'is_favorite': 0,
      'meal': meal,
    });
  }

  /// 기존 기록 갱신 — 결과(result)·끼니(meal) 중 전달된 항목만 반영.
  /// 먹은 양(배수) 변경, 수동 보정, 끼니 태그 변경에 공용으로 사용.
  Future<void> updateAnalysis(int id, {String? result, String? meal}) async {
    final values = <String, Object?>{};
    if (result != null) values['result'] = result;
    if (meal != null) values['meal'] = meal;
    if (values.isEmpty) return;
    final db = await database;
    await db.update(
      'analysis_history',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 전체 기록 조회 (기존 코드 호환용)
  Future<List<Map<String, dynamic>>> getAnalysisHistory() async {
    final db = await database;
    return await db.query('analysis_history', orderBy: 'created_at DESC');
  }

  /// 페이지네이션 + 검색/필터 조회.
  /// [query]는 음식명 검색(result LIKE), [since]는 이 시각 이후 기록만.
  Future<List<Map<String, dynamic>>> getAnalysisHistoryPaged({
    int limit = 20,
    int offset = 0,
    bool favoritesOnly = false,
    String? query,
    DateTime? since,
  }) async {
    final db = await database;
    final (where, args) = _buildFilter(
      favoritesOnly: favoritesOnly,
      query: query,
      since: since,
    );
    return await db.query(
      'analysis_history',
      where: where,
      whereArgs: args,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
  }

  /// favoritesOnly/query/since 조건을 (whereClause, args)로 조립
  (String?, List<Object?>?) _buildFilter({
    required bool favoritesOnly,
    String? query,
    DateTime? since,
  }) {
    final clauses = <String>[];
    final args = <Object?>[];
    if (favoritesOnly) clauses.add('is_favorite = 1');
    final q = query?.trim() ?? '';
    if (q.isNotEmpty) {
      clauses.add('result LIKE ?');
      args.add('%$q%');
    }
    if (since != null) {
      clauses.add('created_at >= ?');
      args.add(since.toIso8601String());
    }
    if (clauses.isEmpty) return (null, null);
    return (clauses.join(' AND '), args);
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
    final rows = await db.query(
      'analysis_history',
      columns: ['image_path'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isNotEmpty) {
      await _deleteImageFile(rows.first['image_path'] as String?);
    }
    await db.delete('analysis_history', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAll() async {
    final db = await database;
    final rows = await db.query('analysis_history', columns: ['image_path']);
    for (final r in rows) {
      await _deleteImageFile(r['image_path'] as String?);
    }
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
