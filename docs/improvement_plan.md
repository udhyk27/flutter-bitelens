# BiteLens 개선 계획

> 우선순위 기준: 사용자 가치 × 구현 난이도

---

## 우선순위 요약

| # | 기능/개선 | 카테고리 | 임팩트 | 난이도 | 우선순위 |
|---|-----------|----------|--------|--------|----------|
| 1 | Cloud Function 인증 (App Check) | 보안 | 🔴 높음 | 쉬움 | **즉시** |
| 2 | 네트워크 에러 처리 & 재시도 | UX | 🔴 높음 | 쉬움 | **즉시** |
| 3 | 음식 일지 (일별 칼로리 목표) | 기능 | 🟠 높음 | 보통 | **단기** |
| 4 | 히스토리 페이지네이션 | 성능 | 🟠 중간 | 쉬움 | **단기** |
| 5 | 영양 트렌드 차트 | 기능 | 🟠 높음 | 보통 | **단기** |
| 6 | 식사 시간대 구분 (아침/점심/저녁) | 기능 | 🟡 중간 | 쉬움 | **중기** |
| 7 | 즐겨찾기 & 자주 먹는 음식 | 기능 | 🟡 중간 | 보통 | **중기** |
| 8 | Firebase Auth 로그인 + 클라우드 동기화 | 기능 | 🟠 높음 | 어려움 | **중기** |
| 9 | 위젯 리팩토링 (파일 분리) | 유지보수 | 🟡 낮음 | 쉬움 | **중기** |
| 10 | 알림 기능 (식사 리마인더) | 기능 | 🟡 중간 | 보통 | **장기** |

---

## Phase 1: 즉시 개선 (1-2주)

### 1. Cloud Function 인증 — Firebase App Check

**문제**: 현재 Cloud Function이 무인증 공개 엔드포인트로 노출되어 있어 Gemini API 비용 무제한 발생 위험이 있음.

**구현 방법**:

**Step 1**: Firebase 콘솔에서 App Check 활성화 (Android: Play Integrity, iOS: DeviceCheck)

**Step 2**: Flutter 앱에 `firebase_app_check` 패키지 추가
```yaml
# pubspec.yaml
firebase_app_check: ^0.3.0
```

**Step 3**: main.dart 초기화
```dart
await FirebaseAppCheck.instance.activate(
  androidProvider: AndroidProvider.playIntegrity,
  appleProvider: AppleProvider.deviceCheck,
);
```

**Step 4**: ResultScreen에서 App Check 토큰을 헤더에 포함
```dart
final token = await FirebaseAppCheck.instance.getToken();
final response = await http.post(
  uri,
  headers: {
    'Content-Type': 'application/json',
    'X-Firebase-AppCheck': token ?? '',
  },
  body: jsonEncode(body),
);
```

**Step 5**: Cloud Function에서 토큰 검증
```javascript
const { initializeApp } = require('firebase-admin/app');
const { getAppCheck } = require('firebase-admin/app-check');

exports.analyzeFood = onRequest(async (req, res) => {
  const appCheckToken = req.header('X-Firebase-AppCheck');
  try {
    await getAppCheck().verifyToken(appCheckToken);
  } catch (err) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }
  // ... 기존 로직
});
```

---

### 2. 네트워크 에러 처리 & 재시도

**문제**: 일시적 네트워크 오류에도 바로 실패, 사용자에게 명확한 원인 미전달.

**구현 방법** (`lib/screens/result_screen.dart` 수정):

```dart
Future<String> _analyzeImage(String base64Image) async {
  const maxRetries = 3;
  for (int attempt = 0; attempt < maxRetries; attempt++) {
    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({...}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['result'];
      } else if (response.statusCode == 429) {
        throw Exception('서버가 혼잡합니다. 잠시 후 다시 시도해주세요.');
      } else {
        throw Exception('서버 오류 (${response.statusCode})');
      }
    } on SocketException {
      if (attempt == maxRetries - 1) {
        throw Exception('네트워크 연결을 확인해주세요.');
      }
      await Future.delayed(Duration(seconds: (attempt + 1) * 2));
    } on TimeoutException {
      if (attempt == maxRetries - 1) {
        throw Exception('분석 시간이 초과되었습니다. 다시 시도해주세요.');
      }
    }
  }
  throw Exception('분석에 실패했습니다.');
}
```

---

## Phase 2: 단기 기능 추가 (2-4주)

### 3. 음식 일지 — 일별 칼로리 목표 달성률

**개요**: 하루 동안 섭취한 칼로리 합계를 TDEE 기준으로 퍼센티지로 보여주는 대시보드 추가.

**구현 방법**:

**Step 1**: HomeScreen 상단에 오늘의 섭취량 요약 배너 추가
```dart
// 오늘 섭취 칼로리 합계
Future<int> _getTodayCalories() async {
  final history = await dbHelper.getAnalysisHistory();
  final today = DateTime.now();
  return history
    .where((r) => _isToday(r['created_at']))
    .map((r) => NutritionParser.parseCalories(r['result']) ?? 0)
    .fold(0, (a, b) => a + b);
}
```

**Step 2**: 원형 프로그레스 위젯으로 시각화
```dart
CircularProgressIndicator(
  value: todayCalories / tdee,
  color: _calColor(todayCalories / tdee),
  backgroundColor: Colors.white12,
)
```

**Step 3**: HistoryScreen 상단에 주간 칼로리 바 차트 추가 (7일 합산)

---

### 4. 히스토리 페이지네이션

**문제**: 기록이 많으면 초기 로드 느려짐.

**구현 방법** (`lib/services/database_service.dart`):

```dart
Future<List<Map<String, dynamic>>> getAnalysisHistoryPaged({
  int limit = 20,
  int offset = 0,
}) async {
  final db = await database;
  return await db.query(
    'analysis_history',
    orderBy: 'created_at DESC',
    limit: limit,
    offset: offset,
  );
}
```

HistoryScreen에서 `ScrollController`로 무한 스크롤 구현:
```dart
_scrollController.addListener(() {
  if (_scrollController.position.pixels >= 
      _scrollController.position.maxScrollExtent - 200) {
    _loadMore();
  }
});
```

---

### 5. 영양 트렌드 차트

**개요**: 7일/30일 단위로 칼로리, 탄수화물, 단백질, 지방 트렌드를 꺾은선 그래프로 표시.

**구현 위치**: HistoryScreen 상단 탭 또는 별도 `TrendScreen`

**구현 방법**:

`NutritionParser` (이미 HistoryScreen에 존재)를 활용해 날짜별 영양소 집계:

```dart
Map<DateTime, NutritionSummary> _aggregateByDay(
  List<Map<String, dynamic>> records,
) {
  final map = <DateTime, NutritionSummary>{};
  for (final r in records) {
    final date = DateTime.parse(r['created_at']).toLocal();
    final key = DateTime(date.year, date.month, date.day);
    final nutrition = NutritionParser.parse(r['result']);
    map[key] = (map[key] ?? NutritionSummary.zero) + nutrition;
  }
  return map;
}
```

기존 `_ChartPainter` (ProfileScreen)를 재사용 가능하도록 공통 위젯으로 추출.

---

## Phase 3: 중기 기능 추가 (1-2개월)

### 6. 식사 시간대 구분

**개요**: 분석 기록을 아침(06-10시)/점심(11-14시)/저녁(17-21시)/간식으로 자동 분류.

**DB 변경 불필요** — `created_at` 타임스탬프에서 시간 추출:
```dart
MealType getMealType(String createdAt) {
  final hour = DateTime.parse(createdAt).toLocal().hour;
  if (hour >= 6 && hour < 11) return MealType.breakfast;
  if (hour >= 11 && hour < 15) return MealType.lunch;
  if (hour >= 17 && hour < 22) return MealType.dinner;
  return MealType.snack;
}
```

HistoryScreen에서 날짜 그룹 내 시간대별 서브그룹으로 표시.

---

### 7. 즐겨찾기 & 자주 먹는 음식

**개요**: 자주 분석한 음식을 북마크하거나 상위 5개를 자동 추천.

**DB 변경**:
```sql
ALTER TABLE analysis_history ADD COLUMN is_favorite INTEGER DEFAULT 0;
```

**구현**:
- HistoryScreen 카드에 별 아이콘 토글
- HomeScreen 드로어에 "즐겨찾기" 메뉴 추가
- 음식 이름 기준으로 빈도 집계 (food_name 컬럼 활성화 필요)

---

### 8. Firebase Auth + 클라우드 동기화

**개요**: 구글 소셜 로그인으로 기록을 Firestore에 동기화해 기기 간 공유 가능.

**구현 단계**:

1. `google_sign_in` 패키지 추가
2. Firebase Auth Google 로그인 구현
3. Firestore 스키마 정의:
   ```
   users/{uid}/
     ├── profile (document)
     └── history/{id} (collection)
   ```
4. SQLite ↔ Firestore 양방향 동기화 로직
5. 오프라인 우선 전략 (Firestore persistence 활성화)
6. 로그아웃 시 로컬 데이터 유지

**주의**: Firestore 보안 규칙으로 `uid` 기반 접근 제어 필수

---

### 9. 위젯 리팩토링 (파일 분리)

현재 화면별 파일이 너무 큽니다. 다음 구조로 분리를 권고합니다:

```
lib/
├── screens/
│   ├── home_screen.dart       (~100줄)
│   ├── result_screen.dart     (~200줄)
│   └── ...
└── widgets/
    ├── result/
    │   ├── nutrition_card.dart
    │   ├── tdee_banner.dart
    │   └── scan_frame_painter.dart
    ├── history/
    │   ├── history_card.dart
    │   └── nutrition_bar.dart
    ├── profile/
    │   ├── weight_chart.dart
    │   ├── bmi_gauge_bar.dart
    │   └── metric_card.dart
    └── common/
        └── profile_nudge_banner.dart
```

---

## Phase 4: 장기 기능 추가 (2-3개월)

### 10. 식사 리마인더 알림

**개요**: 설정한 시간에 식사 기록 유도 알림 발송.

**구현**:
1. `flutter_local_notifications` + `timezone` 패키지 추가
2. SettingsScreen에 알림 시간 설정 UI 추가
3. 스케줄 알림 등록:
   ```dart
   await flutterLocalNotificationsPlugin.zonedSchedule(
     0,
     '점심 식사는 하셨나요?',
     '오늘 섭취량을 기록해보세요',
     scheduledTime,
     ...
   );
   ```

---

### 11. 바코드 스캔으로 가공식품 분석

**개요**: 카메라로 제품 바코드를 스캔하면 공공 식품 DB에서 영양정보 조회.

**구현**:
1. `mobile_scanner` 패키지 추가 (카메라 화면 바코드 감지)
2. 한국 식품안전처 오픈 API 또는 Open Food Facts API 연동
3. HomeScreen에 바코드 스캔 버튼 추가

---

### 12. Apple Watch / Wear OS 연동

**개요**: 손목에서 빠른 칼로리 조회 가능.

현재 Flutter 에코시스템에서는 `watch_connectivity` 패키지로 기본 데이터 동기화 가능. 단 UI는 네이티브 개발 필요.

---

## 기술 부채 해소 계획

| 항목 | 파일 | 예상 소요 |
|------|------|-----------|
| DB `food_name`/`calories` 컬럼 활성화 또는 제거 | `database_service.dart` | 1시간 |
| 이미지 절대경로 → 앱 내부 상대경로 마이그레이션 | `database_service.dart`, `result_screen.dart` | 3시간 |
| `ProfileNudgeBanner` 공통 위젯 추출 | `home_screen.dart`, `result_screen.dart` | 1시간 |
| 단위 테스트 작성 (NutritionParser, 건강지표 계산) | `test/` | 4시간 |
| 통합 테스트 작성 (DB CRUD, 화면 전환) | `integration_test/` | 8시간 |
