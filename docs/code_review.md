# BiteLens 코드 리뷰

> 리뷰 기준: 코드 품질, 보안, 성능, 유지보수성

---

## 총평

전반적으로 기능이 잘 동작하는 프로덕션 수준의 앱입니다. Flutter 기본 패턴을 충실히 따르고 있으며 UI 완성도가 높습니다. 다만 파일 크기, 보안, 에러 처리 측면에서 개선이 필요한 부분이 있습니다.

| 항목 | 점수 | 코멘트 |
|------|------|--------|
| 기능 완성도 | ⭐⭐⭐⭐☆ | 핵심 기능 모두 동작 |
| 코드 구조 | ⭐⭐⭐☆☆ | 파일 분리는 되어있으나 일부 파일 비대 |
| 보안 | ⭐⭐☆☆☆ | API 인증 없음, 공개 엔드포인트 |
| 성능 | ⭐⭐⭐☆☆ | compute() 사용은 좋으나 페이지네이션 부재 |
| 에러 처리 | ⭐⭐☆☆☆ | try-catch는 있으나 사용자 피드백 빈약 |
| 테스트 | ⭐☆☆☆☆ | 테스트 코드 없음 |

---

## 잘 된 점

### 1. 이미지 처리 최적화
`result_screen.dart`에서 `compute()` 함수를 사용해 JPEG 변환을 별도 isolate에서 실행하고 있습니다. UI 스레드 블로킹 없이 이미지를 처리하는 올바른 패턴입니다.

```dart
// 좋은 패턴: compute()로 별도 thread에서 변환
final converted = await compute(_convertToJpeg, imagePath);
```

### 2. JPEG 포맷 감지
파일 확장자 대신 매직 바이트(0xFFD8FF)로 JPEG 여부를 판단합니다. 더 신뢰성 높은 방식입니다.

```dart
bool isJpeg = bytes.length >= 3 &&
    bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
```

### 3. Singleton 패턴 일관성
`Api`와 `DatabaseHelper` 모두 싱글톤 패턴을 사용하고 지연 초기화(lazy init)를 적용하여 리소스를 효율적으로 관리합니다.

### 4. 조건부 기록 저장
영양 정보가 파싱되지 않으면 기록을 저장하지 않는 방어적 코딩이 잘 되어있습니다.

```dart
// 영양소 데이터가 있을 때만 저장
if (widget.saveHistory && hasNutritionData) {
  await dbHelper.insertAnalysis(...);
}
```

### 5. 커스텀 페인팅 활용
`_ChartPainter`, `_FramePainter`, `_BmiGaugeBar` 등 `CustomPainter`를 적극 활용하여 외부 차트 라이브러리 없이도 품질 높은 시각화를 구현했습니다.

---

## 개선이 필요한 점

### [HIGH] 보안: Cloud Function 인증 없음

**파일**: `functions/index.js`

현재 Cloud Function 엔드포인트가 인증 없이 공개되어 있습니다. 누구나 해당 URL로 요청을 보내 Gemini API를 무제한 사용할 수 있습니다.

```javascript
// 현재: 인증 없음
exports.analyzeFood = onRequest(async (req, res) => {
  // 모든 요청 허용
```

**권고**: Firebase App Check 적용 또는 Firebase Auth 토큰 검증 추가

```javascript
// 권고: App Check 또는 ID Token 검증
const appCheck = req.headers['x-firebase-appcheck'];
// 또는
const idToken = req.headers.authorization?.split('Bearer ')[1];
```

---

### [HIGH] 에러 처리 불충분

**파일**: `lib/screens/result_screen.dart`

네트워크 오류, 타임아웃, 서버 오류 등을 구분하지 않고 동일한 메시지를 표시합니다. 사용자가 문제를 파악하기 어렵습니다.

```dart
// 현재: 모든 오류를 동일하게 처리
catch (e) {
  setState(() => _errorMessage = '오류가 발생했습니다.');
}
```

**권고**: 오류 유형 분류 및 재시도 로직 추가

```dart
catch (e) {
  if (e is SocketException) {
    _errorMessage = '네트워크 연결을 확인해주세요.';
  } else if (e is TimeoutException) {
    _errorMessage = '요청 시간이 초과되었습니다. 다시 시도해주세요.';
  } else {
    _errorMessage = '분석 중 오류가 발생했습니다.';
  }
}
```

---

### [MEDIUM] 페이지네이션 없이 전체 기록 로드

**파일**: `lib/screens/history_screen.dart`, `lib/services/database_service.dart`

```dart
// 현재: 전체 기록 한번에 로드
Future<List<Map<String, dynamic>>> getAnalysisHistory() async {
  return await db.query('analysis_history', orderBy: 'created_at DESC');
}
```

기록이 수백 건 이상 쌓이면 메모리 사용량 증가 및 초기 로드 속도 저하가 발생합니다.

**권고**: LIMIT/OFFSET 기반 페이지네이션 또는 `flutter_list_view`의 lazy loading 적용

---

### [MEDIUM] 파일 크기 과대

일부 파일이 지나치게 큽니다. UI 컴포넌트를 별도 파일로 분리하면 유지보수가 쉬워집니다.

| 파일 | 현재 줄 수 | 권고 |
|------|-----------|------|
| `result_screen.dart` | ~710줄 | `widgets/result/` 디렉토리로 분리 |
| `profile_screen.dart` | ~850줄 | `widgets/profile/` 디렉토리로 분리 |
| `history_screen.dart` | ~630줄 | `widgets/history/` 디렉토리로 분리 |

---

### [MEDIUM] DB 컬럼 미사용

**파일**: `lib/services/database_service.dart`

`analysis_history` 테이블의 `food_name`, `calories` 컬럼이 생성되어 있지만 항상 `null`로 저장되고 읽히지 않습니다. 쿼리 시 파싱하거나 컬럼을 제거해야 합니다.

---

### [MEDIUM] 네트워크 재시도 로직 없음

**파일**: `lib/screens/result_screen.dart`

일시적인 네트워크 오류나 서버 과부하 시 자동 재시도 없이 바로 오류를 표시합니다.

**권고**: exponential backoff로 최대 3회 재시도 구현

```dart
Future<http.Response> _postWithRetry(Uri url, Map body, {int retries = 3}) async {
  for (int i = 0; i < retries; i++) {
    try {
      final res = await http.post(url, ...).timeout(Duration(seconds: 30));
      if (res.statusCode == 200) return res;
    } catch (_) {
      if (i == retries - 1) rethrow;
      await Future.delayed(Duration(seconds: (i + 1) * 2));
    }
  }
  throw Exception('Max retries exceeded');
}
```

---

### [LOW] 하드코딩된 문자열

설정 화면에서 응답 언어를 한/영/일로 바꿀 수 있지만, 앱 UI 자체는 한국어로 고정되어 있습니다. `flutter_localizations`와 ARB 파일로 국제화를 적용하면 앱 스토어 글로벌 배포에 유리합니다.

---

### [LOW] analysis_history 이미지 경로 관리

**파일**: `lib/services/database_service.dart`

`image_path`에 기기 내 절대 경로를 저장합니다. 앱 재설치, OS 업데이트, 기기 이전 시 경로가 깨질 수 있습니다.

**권고**: 앱 문서 디렉토리 내 복사본 저장 후 상대 경로 사용

```dart
// 권고: 앱 내부 디렉토리에 이미지 복사
final appDir = await getApplicationDocumentsDirectory();
final savedPath = '${appDir.path}/history/${timestamp}.jpg';
await File(imagePath).copy(savedPath);
```

---

### [LOW] ProfileNudgeBanner 코드 중복

`ProfileNudgeBanner`가 `home_screen.dart`와 `result_screen.dart` 두 곳에서 사용됩니다. 공통 위젯으로 분리하면 좋습니다.

**권고**: `lib/widgets/profile_nudge_banner.dart`로 추출

---

## 긍정적 패턴 요약

1. `compute()`로 이미지 변환 offloading ✅
2. 매직 바이트로 파일 형식 감지 ✅
3. `mounted` 체크로 위젯 생명주기 관리 ✅
4. 조건부 기록 저장 로직 ✅
5. CustomPainter 직접 구현으로 외부 의존성 최소화 ✅
6. Singleton + 지연 초기화 패턴 ✅
7. Firebase Remote Config로 AI 모델 원격 제어 ✅
