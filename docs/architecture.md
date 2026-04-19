# BiteLens 아키텍처 문서

## 프로젝트 개요

**BiteLens**는 AI 기반 음식 분석 Flutter 앱입니다. 카메라로 음식을 촬영하면 Gemini AI가 칼로리 및 영양소를 분석해 알려주고, 사용자의 TDEE(일일 총 에너지 소비량) 대비 섭취량을 시각화합니다.

- **버전**: 1.0.0+3
- **Flutter/Dart SDK**: Dart 3.10.4
- **지원 플랫폼**: iOS, Android (주력), Web, macOS, Linux, Windows
- **백엔드**: Firebase (Cloud Functions + Remote Config + Firestore)
- **AI**: Google Gemini API (gemini-2.5-flash-lite)

---

## 전체 아키텍처

```
┌──────────────────────────────────────────────────────┐
│                    Flutter App                       │
│                                                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐  │
│  │  Screens │  │ Services │  │    Local Storage  │  │
│  │          │  │          │  │                   │  │
│  │ • Home   │  │ • API    │  │ • SQLite (sqflite)│  │
│  │ • Result │  │   Service│  │   - analysis_hist │  │
│  │ • History│  │ • DB     │  │   - weight_log    │  │
│  │ • Profile│  │   Service│  │ • SharedPrefs     │  │
│  │ • Setting│  │          │  │   - user profile  │  │
│  │ • Onboard│  │          │  │   - app settings  │  │
│  └──────────┘  └──────────┘  └──────────────────┘  │
└───────────────────────┬──────────────────────────────┘
                        │ HTTP / Firebase SDK
          ┌─────────────┴─────────────┐
          │                           │
   ┌──────▼──────┐           ┌────────▼───────┐
   │  Firebase   │           │  Cloud Function │
   │             │           │  analyzeFood   │
   │ • Remote    │           │  (Node.js)     │
   │   Config    │           │                │
   │ • Analytics │           │  Gemini API    │
   │ • Auth      │           │  (gemini-2.5-  │
   │ • Firestore │           │   flash-lite)  │
   └─────────────┘           └────────────────┘
```

---

## 레이어 구조

### 1. Presentation Layer (lib/screens/)

| 파일 | 역할 | 주요 위젯 |
|------|------|-----------|
| `main.dart` | 앱 진입점, 스플래시 화면 | `AnimatedSplash` |
| `home_screen.dart` | 카메라 캡처 인터페이스 | `HomeScreen`, `_ScanFrame`, `_ShutterButton` |
| `result_screen.dart` | AI 분석 결과 표시 | `ResultScreen`, `_NutritionCard`, `_TdeeBanner` |
| `history_screen.dart` | 분석 기록 열람/삭제 | `HistoryScreen`, `_HistoryCard` |
| `profile_screen.dart` | 신체정보 입력 + 체중 추적 | `ProfileScreen`, `_WeightChart` |
| `settings_screen.dart` | 앱 설정 | `SettingsScreen` |
| `onboarding_screen.dart` | 최초 진입 온보딩 | `OnboardingScreen` |
| `webview_screen.dart` | 약관/정책 WebView | `WebViewScreen` |

### 2. Service Layer (lib/services/)

| 파일 | 역할 | 패턴 |
|------|------|------|
| `api_service.dart` | Firebase Remote Config 관리 | Singleton |
| `database_service.dart` | SQLite CRUD 조작 | Singleton + Lazy Init |

### 3. Constants Layer (lib/constants/)

| 파일 | 내용 |
|------|------|
| `svg_constant.dart` | 스플래시용 SVG 애니메이션 로고 |

---

## 상태 관리

**방식**: Flutter 기본 `StatefulWidget` (외부 상태 관리 라이브러리 미사용)

각 화면이 독립적인 상태를 관리하며, 화면 간 데이터는 생성자 인자 또는 SharedPreferences/SQLite를 통해 공유합니다.

```
HomeScreen → (imagePath) → ResultScreen
                                ↓
                         SQLite analysis_history
                                ↓
                         HistoryScreen (reads DB)
```

SharedPreferences를 통한 전역 상태:
- 사용자 프로필 (성별, 나이, 키, 체중, 활동량, TDEE)
- 앱 설정 (기록 저장 여부, 상세 분석, 응답 언어)
- 온보딩 완료 여부

---

## 데이터 흐름

### 음식 분석 흐름

```
1. 카메라 캡처 / 갤러리 선택
        ↓
2. JPEG 압축 (image 패키지, compute()로 별도 thread)
        ↓
3. Base64 인코딩
        ↓
4. HTTP POST → Cloud Function (analyzefood-mfdr4grlbq-uc.a.run.app)
        ↓
5. Gemini API 프롬프트 실행
        ↓
6. 구조화된 텍스트 응답 반환
        ↓
7. Regex 파싱 (칼로리, 탄수화물, 단백질, 지방)
        ↓
8. UI 렌더링 + SQLite 저장 (save_history=true일 때)
```

### Cloud Function 요청/응답

**요청**:
```json
{
  "imageBase64": "...",
  "detailedAnalysis": false,
  "language": "한국어",
  "aiModel": "gemini-2.5-flash-lite"
}
```

**응답**:
```json
{
  "result": "음식 이름: 김치찌개\n예상 칼로리: 350 kcal\n탄수화물: 20g\n단백질: 15g\n지방: 12g"
}
```

---

## 로컬 데이터베이스 스키마

### analysis_history 테이블
```sql
CREATE TABLE analysis_history (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  image_path  TEXT NOT NULL,
  food_name   TEXT,          -- 현재 미사용
  calories    TEXT,          -- 현재 미사용
  result      TEXT NOT NULL, -- AI 전체 응답 원문
  created_at  TEXT NOT NULL  -- ISO8601 타임스탬프
)
```

### weight_log 테이블
```sql
CREATE TABLE weight_log (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  weight    REAL NOT NULL,
  logged_at TEXT NOT NULL    -- ISO8601 타임스탬프
)
```

---

## Firebase Remote Config 변수

| 키 | 설명 |
|----|------|
| `ai_model` | Gemini 모델 선택 (기본값: gemini-2.5-flash-lite) |
| `app_version_aos` | 설정 화면에 표시할 앱 버전 |
| `store_aos` | Google Play 스토어 링크 |
| `privacy` | 개인정보 처리방침 URL |
| `terms` | 이용약관 URL |

---

## 건강 지표 계산 공식

### BMI
```
BMI = 체중(kg) / (키(m))²
```

### BMR (Harris-Benedict 공식)
```
남성: 66.5 + (13.75 × 체중) + (5.003 × 키) - (6.75 × 나이)
여성: 655.1 + (9.563 × 체중) + (1.850 × 키) - (4.676 × 나이)
```

### TDEE
```
TDEE = BMR × 활동량 계수
  비활동적 (1.2) / 가벼운 활동 (1.375) / 보통 활동 (1.55)
  활동적 (1.725) / 매우 활동적 (1.9)
```

---

## 내비게이션 구조

```
main.dart
  ├── OnboardingScreen (최초 실행 시)
  │     └── HomeScreen (완료 후)
  └── HomeScreen (재실행 시)
        ├── ResultScreen (촬영/선택 후)
        ├── HistoryScreen (Drawer 메뉴)
        ├── ProfileScreen (Drawer 메뉴)
        └── SettingsScreen (Drawer 메뉴)
              └── WebViewScreen (약관/정책 링크)
```

네비게이션 방식: `MaterialPageRoute` 기반 스택 네비게이션 (named route 미사용)

---

## UI 디자인 시스템

**테마**: 다크 모드 전용

| 요소 | 값 |
|------|-----|
| 배경색 | `#000000` / `#111111` / `#1A1A1A` |
| 강조색 | `Colors.deepOrange` / `#FF6500` |
| 탄수화물 색 | `Colors.blue.shade300` |
| 단백질 색 | `Colors.green.shade400` |
| 지방 색 | `Colors.orange.shade300` |
| 테두리 반경 | 12–16px |

---

## 의존성 목록

| 패키지 | 버전 | 용도 |
|--------|------|------|
| camera | ^0.11.2 | 실시간 카메라 캡처 |
| google_generative_ai | ^0.4.6 | Gemini AI (Flutter 측 미사용, 함수에서 사용) |
| flutter_dotenv | ^5.1.0 | 환경변수 관리 |
| image_picker | ^1.1.2 | 갤러리 이미지 선택 |
| sqflite | ^2.3.3 | 로컬 SQLite DB |
| share_plus | ^10.0.0 | 결과 공유 |
| url_launcher | ^6.3.0 | 외부 URL 열기 |
| shared_preferences | ^2.3.0 | 키-값 영구 저장 |
| image | ^4.1.0 | 이미지 압축/변환 |
| webview_flutter | ^4.0.0 | 약관/정책 WebView |
| http | ^1.0.0 | HTTP 요청 |
| connectivity_plus | ^6.0.0 | 네트워크 상태 감지 |
| firebase_core | ^3.10.1 | Firebase 초기화 |
| firebase_remote_config | ^5.5.0 | 원격 설정 |
| cloud_firestore | ^5.6.2 | 클라우드 DB (최소 사용) |
| firebase_auth | ^5.4.1 | 인증 (최소 사용) |
| firebase_analytics | ^11.4.2 | 앱 분석 |
| flutter_inappwebview | ^6.1.5 | 스플래시 인앱 브라우저 |
