# BiteLens

AI 기반 음식 칼로리 분석 Flutter 앱입니다. 음식을 촬영하거나 갤러리에서 선택하면 Gemini가 음식 이름, 예상 칼로리, 주요 영양소를 분석하고, 사용자의 TDEE 기준으로 섭취량을 비교합니다.

## 주요 기능

- 카메라 촬영 및 갤러리 이미지 분석
- Gemini 기반 음식 이름, 칼로리, 탄수화물, 단백질, 지방 분석
- Firebase App Check로 Cloud Function 요청 보호
- 분석 기록 로컬 저장, 즐겨찾기, 삭제, 공유
- 주간 칼로리 차트와 날짜별 기록 보기
- 신체 정보 기반 BMI, BMR, TDEE 계산
- 체중 로그 및 추이 그래프
- 응답 언어 선택: 한국어, English, 日本語
- Remote Config 기반 AI 모델, 앱 버전, 약관 URL 관리

## 기술 스택

| 영역 | 기술 |
| --- | --- |
| App | Flutter, Dart |
| Camera/Image | camera, image_picker, image |
| Local Storage | sqflite, shared_preferences |
| Backend | Firebase Cloud Functions v2 |
| AI | Google Gemini API |
| Firebase | Core, Remote Config, App Check, Analytics |
| WebView/Share | webview_flutter, flutter_inappwebview, share_plus |

## 프로젝트 구조

```text
lib/
  main.dart                    # 앱 초기화, Splash, 온보딩 분기
  constants/
    svg_constant.dart          # 스플래시 로고 SVG
  screens/
    home_screen.dart           # 카메라, 갤러리, 메인 드로어
    onboarding_screen.dart     # 최초 실행 온보딩
    result_screen.dart         # AI 분석 요청 및 결과 표시
    history_screen.dart        # 분석 기록, 즐겨찾기, 주간 차트
    profile_screen.dart        # BMI/BMR/TDEE, 체중 기록
    settings_screen.dart       # 분석/언어/데이터/앱 정보 설정
    webview_screen.dart        # 약관/개인정보처리방침 WebView
  services/
    api_service.dart           # Firebase Remote Config
    database_service.dart      # SQLite CRUD

functions/
  index.js                     # analyzeFood Cloud Function
```

## 분석 흐름

```text
카메라 촬영 / 갤러리 선택
  -> 이미지 JPEG 변환
  -> Base64 인코딩
  -> Firebase App Check 토큰 첨부
  -> Cloud Function analyzeFood 호출
  -> Gemini 분석
  -> 결과 표시
  -> SQLite 기록 저장
```

## 로컬 실행

### 1. Flutter 의존성 설치

```bash
flutter pub get
```

### 2. Firebase 설정

이 프로젝트는 Firebase 초기화와 App Check를 사용합니다. 실제 실행 전 Firebase 프로젝트 설정 파일이 플랫폼별로 준비되어 있어야 합니다.

- Android: `android/app/google-services.json`
- iOS: `ios/Runner/GoogleService-Info.plist`
- macOS: `macos/Runner/GoogleService-Info.plist`

개발 빌드에서는 Firebase App Check debug provider를 사용합니다. 앱 실행 로그에 출력되는 debug token을 Firebase Console의 App Check debug token 목록에 등록해야 Cloud Function 호출이 정상 동작합니다.

### 3. 앱 실행

```bash
flutter run
```

## Cloud Functions

Cloud Function은 `functions/index.js`의 `analyzeFood`입니다.

### 의존성 설치

```bash
cd functions
npm install
```

### Gemini API Secret 등록

```bash
firebase functions:secrets:set GEMINI_API_KEY
```

### 배포

```bash
firebase deploy --only functions
```

## Remote Config 키

| 키 | 설명 |
| --- | --- |
| `ai_model` | Gemini 모델명 |
| `app_version_aos` | 앱 버전 표시 |
| `store_aos` | Android 스토어 URL |
| `privacy` | 개인정보 처리방침 URL |
| `terms` | 이용약관 URL |

## 로컬 데이터

SQLite 데이터베이스 `bitelens.db`에 다음 테이블을 사용합니다.

- `analysis_history`: 이미지 경로, AI 응답 원문, 생성 시각, 즐겨찾기 여부
- `weight_log`: 체중, 기록 시각

SharedPreferences에는 온보딩 완료 여부, 사용자 신체 정보, TDEE, 분석 설정, 응답 언어를 저장합니다.

## 검증

```bash
flutter analyze
flutter test
```

현재 테스트는 기본 Flutter 템플릿 테스트가 남아 있으면 실패할 수 있습니다. 앱 구조에 맞는 위젯 테스트로 교체하는 것이 필요합니다.

## 문서

상세 문서는 `docs/`에서 확인할 수 있습니다.

- `docs/architecture.md`
- `docs/implementation_status.md`
- `docs/troubleshooting.md`
- `docs/code_review.md`
- `docs/improvement_plan.md`
