import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:bitelens/services/database_service.dart';

void main() {
  late Database db;
  late DatabaseHelper helper;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
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
    helper = DatabaseHelper.forTesting(db);

    final records = [
      ('Kimchi stew', '300', '2026-11-26T12:00:00.000', 1),
      ('Apple', '95', '2026-11-26T08:00:00.000', 0),
      ('Chicken soup', '420', '2026-11-25T19:00:00.000', 1),
      ('Kimchi fried rice', '510', '2026-11-24T12:00:00.000', 0),
    ];
    for (final (name, calories, createdAt, favorite) in records) {
      await db.insert('analysis_history', {
        'image_path': '',
        'food_name': name,
        'calories': calories,
        'result': '{}',
        'created_at': createdAt,
        'is_favorite': favorite,
      });
    }
  });

  tearDown(() => db.close());

  test('검색·즐겨찾기·날짜 조건을 함께 적용한다', () async {
    final rows = await helper.getAnalysisHistoryPaged(
      favoritesOnly: true,
      query: ' kimchi ',
      since: DateTime(2026, 11, 25),
    );

    expect(rows.map((row) => row['food_name']), ['Kimchi stew']);
  });

  test('페이지네이션은 최신순으로 안정적으로 나눈다', () async {
    final firstPage = await helper.getAnalysisHistoryPaged(limit: 2);
    final secondPage = await helper.getAnalysisHistoryPaged(
      limit: 2,
      offset: 2,
    );

    expect(firstPage.map((row) => row['food_name']), ['Kimchi stew', 'Apple']);
    expect(secondPage.map((row) => row['food_name']), [
      'Chicken soup',
      'Kimchi fried rice',
    ]);
    expect(await helper.getAnalysisCount(favoritesOnly: true), 2);
  });

  test('날짜별 칼로리 합계는 페이지와 무관하게 전체 기록을 합산한다', () async {
    expect(await helper.getDailyCalorieTotals(), {
      '2026-11-26': 395,
      '2026-11-25': 420,
      '2026-11-24': 510,
    });
    expect(
      await helper.getDailyCalorieTotals(favoritesOnly: true, query: 'soup'),
      {'2026-11-25': 420},
    );
  });
}
