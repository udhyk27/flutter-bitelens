# BiteLens 구현 현황

> 최종 업데이트: 2026-04-19

---

## 전체 구현 진행률

| 영역 | 상태 | 완성도 |
|------|------|--------|
| 카메라 캡처 & 갤러리 선택 | ✅ 완료 | 100% |
| AI 음식 분석 (Cloud Function) | ✅ 완료 | 100% |
| 분석 결과 화면 | ✅ 완료 | 90% |
| 분석 기록 저장 & 열람 | ✅ 완료 | 85% |
| 프로필 & 건강 지표 계산 | ✅ 완료 | 90% |
| 체중 추적 & 그래프 | ✅ 완료 | 80% |
| 앱 설정 | ✅ 완료 | 95% |
| 온보딩 | ✅ 완료 | 100% |
| 다국어 지원 (한/영/일) | ✅ 완료 | 80% |
| Firebase 인증 | ⚠️ 설정만 됨 | 10% |
| Firestore 연동 | ⚠️ 설정만 됨 | 5% |
| 에러 핸들링 | ⚠️ 기본 수준 | 40% |
| 테스트 코드 | ❌ 없음 | 0% |

---

## 화면별 구현 상세

### HomeScreen (`lib/screens/home_screen.dart`, ~380줄)
- [x] 실시간 카메라 프리뷰
- [x] 커스텀 스캔 프레임 오버레이 (`_FramePainter`)
- [x] 셔터 버튼 펄스 애니메이션
- [x] 갤러리 이미지 선택
- [x] 드로어 네비게이션 메뉴
- [x] 카메라 권한 처리
- [x] 프로필 미설정 시 빨간 점 표시 (`ProfileNudgeBanner`)
- [ ] 연속 촬영 모드
- [ ] 줌 제어

### ResultScreen (`lib/screens/result_screen.dart`, ~710줄)
- [x] 스캔 애니메이션 (주황 그라데이션 라인)
- [x] Cloud Function HTTP POST
- [x] 응답 텍스트 파싱 (Regex)
- [x] 칼로리 vs TDEE 비교 바 (`_TdeeBanner`)
- [x] 영양소 비율 시각화 (`_NutritionCard`)
- [x] 결과 공유 기능
- [x] SQLite 기록 저장 (조건부)
- [ ] 오프라인 캐시 / 재시도 로직
- [ ] 상세 분석 시 나트륨/식이섬유 별도 UI 표시

### HistoryScreen (`lib/screens/history_screen.dart`, ~630줄)
- [x] 날짜별 그룹핑 (오늘/어제/날짜)
- [x] 일일 총 칼로리 합산
- [x] 하단 시트 상세 보기
- [x] 개별 기록 삭제 (확인 다이얼로그)
- [x] 개별 기록 공유
- [x] 섬네일 이미지 표시
- [ ] 페이지네이션 (현재 전체 로드)
- [ ] 날짜 범위 필터
- [ ] 칼로리 추이 차트

### ProfileScreen (`lib/screens/profile_screen.dart`, ~850줄)
- [x] 성별 토글
- [x] 나이/키/체중/활동량 입력
- [x] BMI 계산 & 게이지 바
- [x] BMR 계산 (Harris-Benedict)
- [x] TDEE 계산 (활동량 계수 5단계)
- [x] 체중 기록 추가
- [x] 체중 추이 라인 차트 (`_ChartPainter`)
- [x] 최근 10개 체중 기록 목록
- [ ] 체중 기록 삭제
- [ ] 목표 체중 설정
- [ ] 체중 변화 알림

### SettingsScreen (`lib/screens/settings_screen.dart`, ~460줄)
- [x] 분석 기록 저장 토글
- [x] 상세 분석 토글
- [x] 응답 언어 선택 (한/영/일)
- [x] 전체 기록 삭제
- [x] 개인정보 처리방침 (WebView)
- [x] 이용약관 (WebView)
- [x] 오픈소스 라이선스
- [x] 앱 버전 표시
- [ ] 알림 설정
- [ ] 앱 아이콘 테마 변경

### OnboardingScreen (`lib/screens/onboarding_screen.dart`, ~295줄)
- [x] 3단계 캐러셀 (PageView)
- [x] 페이지 인디케이터 애니메이션
- [x] 다음/건너뛰기 버튼
- [x] 내 정보 입력 → ProfileScreen 연결
- [x] 나중에 설정 → HomeScreen 이동

---

## 백엔드 구현 현황

### Cloud Function (functions/index.js, ~90줄)
- [x] 이미지 Base64 수신
- [x] Gemini API 호출
- [x] 한/영/일 3개 언어 프롬프트
- [x] 일반/상세 분석 모드
- [x] CORS 설정
- [ ] 요청 인증 (현재 공개 엔드포인트)
- [ ] 속도 제한 (Rate limiting)
- [ ] 에러 코드 세분화
- [ ] 응답 캐싱

### Firebase
- [x] Remote Config (ai_model, 버전, 스토어 URL, 약관 URL)
- [x] Analytics 초기화
- [x] Authentication 초기화
- [ ] Firebase Auth 실제 로그인 플로우
- [ ] Firestore 데이터 동기화
- [ ] Cloud Messaging (푸시 알림)

---

## 알려진 버그 & 기술 부채

| 분류 | 내용 | 우선순위 |
|------|------|----------|
| DB | `food_name`, `calories` 컬럼이 analysis_history에 존재하지만 미사용 | 낮음 |
| 보안 | Cloud Function 엔드포인트가 인증 없이 공개됨 | 높음 |
| 성능 | 기록 전체를 한번에 메모리에 로드 (페이지네이션 없음) | 중간 |
| UX | 에러 메시지가 너무 포괄적 ("오류가 발생했습니다") | 중간 |
| UX | 네트워크 재시도 로직 없음 | 중간 |
| 유지보수 | 하드코딩된 한국어 문자열 (국제화 미적용) | 낮음 |
| 유지보수 | 테스트 코드 없음 | 중간 |
| 아키텍처 | 화면 내 UI 컴포넌트가 너무 많아 파일 크기 큼 (result_screen.dart 710줄) | 낮음 |
