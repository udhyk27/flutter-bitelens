# BiteLens 트러블슈팅 가이드

> 발생한 문제와 해결 방법을 기록합니다.

---

## [보안] Cloud Function 미인증 공개 노출

### 문제

`analyzeFood` Cloud Function이 인증 없이 공개 엔드포인트로 노출되어 있었습니다.

```
POST https://analyzefood-mfdr4grlbq-uc.a.run.app
Content-Type: application/json

{ "imageBase64": "...", "language": "한국어" }
```

위 요청은 앱을 설치하지 않은 **누구나** 보낼 수 있었습니다. 악용 시나리오:

- 경쟁사나 악의적 사용자가 URL을 발견해 자동화 스크립트로 수천 건 요청 → **Gemini API 사용 요금 폭탄**
- 응답 속도 저하 (합법적 사용자에게 영향)
- Gemini API 쿼터 소진

**이전 코드 (`functions/index.js`):**
```javascript
exports.analyzeFood = onRequest(
  { secrets: [GEMINI_API_KEY] },
  async (req, res) => {
    // ← 여기 아무 인증 없이 바로 Gemini API 호출
    const { imageBase64, detailedAnalysis, language, aiModel } = req.body;
    ...
  }
);
```

---

### 해결책: Firebase App Check

**Firebase App Check**는 요청이 실제 등록된 앱(Google Play에 등록된 APK 또는 App Store 앱)에서 왔는지 구글이 서명한 토큰으로 검증하는 시스템입니다.

```
앱 실행
  → Android: Play Integrity API 호출
  → iOS: Apple DeviceCheck 호출
  → Firebase: 서명된 짧은 수명 토큰 발급
  → 앱: HTTP 헤더에 토큰 포함해 Cloud Function 호출
  → Cloud Function: firebase-admin으로 토큰 검증
  → 유효하면 처리, 아니면 401 반환
```

외부에서 URL만 알고 호출하면 유효한 토큰이 없으므로 **무조건 401 Unauthorized**로 차단됩니다.

---

### 변경된 파일과 코드

#### 1. `functions/index.js` — 서버 측 토큰 검증 추가

```javascript
// 추가된 import
const { initializeApp } = require("firebase-admin/app");
const { getAppCheck } = require("firebase-admin/app-check");

initializeApp(); // Firebase Admin 초기화

exports.analyzeFood = onRequest(
  { secrets: [GEMINI_API_KEY] },
  async (req, res) => {

    // ── 추가된 App Check 검증 블록 ──
    const appCheckToken = req.header("X-Firebase-AppCheck");
    if (!appCheckToken) {
      res.status(401).json({ error: "Unauthorized: App Check token required" });
      return;
    }
    try {
      await getAppCheck().verifyToken(appCheckToken);
    } catch (err) {
      res.status(401).json({ error: "Unauthorized: Invalid App Check token" });
      return;
    }
    // ──────────────────────────────

    // ... 기존 Gemini 호출 로직
  }
);
```

**핵심 원리:**
- `req.header("X-Firebase-AppCheck")` — 클라이언트가 보낸 토큰 추출
- `getAppCheck().verifyToken(token)` — Firebase Admin SDK가 구글 서버와 통신해 토큰 유효성 검증
- 토큰 없거나 위조된 경우 즉시 401 반환, Gemini API 호출 자체가 발생하지 않음

#### 2. `pubspec.yaml` — Flutter 패키지 추가

```yaml
firebase_app_check: ^0.3.1+12
```

#### 3. `lib/main.dart` — 앱 시작 시 App Check 초기화

```dart
await FirebaseAppCheck.instance.activate(
  // 릴리즈 빌드: 구글이 APK 서명을 검증하는 Play Integrity 사용
  // 디버그 빌드: 개발용 UUID 토큰 사용 (콘솔에 등록 필요)
  androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
  appleProvider:   kDebugMode ? AppleProvider.debug   : AppleProvider.deviceCheck,
);
```

`kDebugMode`로 환경을 자동 분기하므로 릴리즈 빌드 시 별도 코드 변경 불필요합니다.

#### 4. `lib/screens/result_screen.dart` — HTTP 요청에 토큰 포함

```dart
// 토큰 발급 (App Check가 캐시 및 자동 갱신 관리)
String? appCheckToken;
try {
  appCheckToken = await FirebaseAppCheck.instance.getToken();
} catch (e) {
  debugPrint('App Check token error: $e');
}

// HTTP 헤더에 포함
final response = await http.post(
  Uri.parse('https://analyzefood-mfdr4grlbq-uc.a.run.app'),
  headers: {
    'Content-Type': 'application/json',
    if (appCheckToken != null) 'X-Firebase-AppCheck': appCheckToken,
  },
  body: jsonEncode({...}),
);
```

---

### Firebase 콘솔 1회 설정 (배포 전 필수)

#### Step 1 — App Check 활성화

1. [Firebase 콘솔](https://console.firebase.google.com) → 프로젝트 `bitelens-d9051` 선택
2. 왼쪽 메뉴 **App Check** 클릭
3. 앱 목록에서 Android / iOS 앱 선택
4. Android: **Play Integrity** 선택 후 저장
5. iOS: **DeviceCheck** 선택 후 저장

#### Step 2 — 개발용 디버그 토큰 등록

에뮬레이터/개발 기기에서는 Play Integrity가 작동하지 않으므로 디버그 토큰이 필요합니다.

1. `kDebugMode` 상태로 앱 실행
2. Flutter 콘솔에 출력되는 내용 확인:
   ```
   I/FirebaseAppCheck: Debug App Check token: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   ```
3. Firebase 콘솔 → App Check → 해당 앱 → **디버그 토큰 관리** → UUID 붙여넣기 → 저장

#### Step 3 — Cloud Function 재배포

```bash
cd functions
firebase deploy --only functions
```

---

### 검증 방법

배포 후 curl로 직접 호출하면 차단되는지 확인:

```bash
# 토큰 없이 호출 → 401 응답이 와야 함
curl -X POST https://analyzefood-mfdr4grlbq-uc.a.run.app \
  -H "Content-Type: application/json" \
  -d '{"imageBase64":"test","language":"한국어"}' \
  -w "\nHTTP Status: %{http_code}\n"

# 예상 응답:
# {"error":"Unauthorized: App Check token required"}
# HTTP Status: 401
```

앱에서는 정상적으로 분석이 작동하면 성공입니다.

---

### 추가 보안 옵션 (선택)

App Check 외에 병행할 수 있는 추가 방어:

| 방법 | 효과 | 복잡도 |
|------|------|--------|
| Firebase Functions Rate Limiting | IP당 분당 호출 제한 | 중간 |
| Cloud Armor (GCP) | DDoS 방어, IP 차단 | 높음 |
| Firebase Auth 필수화 | 로그인한 사용자만 허용 | 중간 |
| 이미지 크기 검증 | 대용량 페이로드 차단 | 낮음 |

현재 App Check만으로도 **비앱 요청은 100% 차단**되므로 일반적인 개인 앱 수준에서는 충분합니다.

---

## [성능] 분석 요청 타임아웃 및 네트워크 오류

### 문제

이전 코드는 네트워크 오류 종류 구분 없이 동일한 메시지 표시, 재시도 없음:

```dart
// 이전
catch (e) {
  setState(() => _result = '오류가 발생했습니다.');
}
```

**발생 상황:**
- 지하철/엘리베이터 등 신호 약한 곳에서 일시적 연결 끊김
- Gemini API 응답 지연 (보통 5~15초, 드물게 30초 초과)
- 서버 과부하 시 503 응답

### 해결책

`lib/screens/result_screen.dart`에 재시도 로직과 오류 분류 추가:

```dart
Future<String> _postWithRetry({...}) async {
  for (int attempt = 0; attempt < 3; attempt++) {
    try {
      final response = await http.post(...)
          .timeout(const Duration(seconds: 30)); // 타임아웃 명시

      if (response.statusCode == 200) return data['result'];
      if (response.statusCode == 401) throw Exception('앱 인증에 실패했습니다. 앱을 재시작해주세요.');
      if (response.statusCode == 429) throw Exception('서버가 혼잡합니다. 잠시 후 다시 시도해주세요.');

    } on TimeoutException {
      if (attempt == 2) rethrow;
      await Future.delayed(Duration(seconds: (attempt + 1) * 2)); // 2초 → 4초 → 포기
    } on SocketException {
      if (attempt == 2) rethrow;
      await Future.delayed(Duration(seconds: (attempt + 1) * 2));
    }
  }
}
```

**개선 효과:**
- 일시적 오류: 최대 3회 자동 재시도 (대기: 2초 → 4초)
- 오류 원인별 사용자 메시지 분리 (네트워크/타임아웃/서버/인증)
- 30초 타임아웃으로 무한 대기 방지
