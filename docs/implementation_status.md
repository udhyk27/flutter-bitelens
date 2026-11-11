# BiteLens 구현 현황

> 최종 확인: 2026-11-10

## 구현된 기능

- 카메라 촬영 및 갤러리 이미지 음식 분석
- Firebase App Check 검증, 이미지 크기·MIME·모델 검증, Gemini 오류 상태 처리 및 재시도
- 분석 결과 편집, 먹은 양 조절, 끼니 태그, 선택적 로컬 저장
- 기록 검색·기간 필터·즐겨찾기·페이지네이션·CSV 내보내기
- 날짜별 칼로리 요약, 주간 차트, 프로필 기반 BMI/BMR/TDEE와 체중 기록
- Remote Config, 분석 언어 선택, 개인정보·약관 화면

## 검증 상태

- `flutter analyze`: 통과 (2026-11-09 확인)
- 테스트: `test/food_analysis_test.dart`에 모델 파싱, 직렬화, 양 조절 테스트가 있음
- DB 마이그레이션, 화면 흐름, Cloud Function을 검증하는 자동화 테스트는 아직 없음
- Firebase 프로젝트 설정 파일은 저장소에서 제외되어 있어 콘솔 설정·배포 상태는 저장소만으로 확인 불가

## 남은 개선

1. 출시 환경에서 App Check, Functions Secret, Cloud Function 배포 및 실제 기기 분석 흐름 확인
2. 홈 일일 통계는 해당 날짜의 DB 행만 읽도록 최적화
3. DB/검색/페이지네이션/CSV 안전성 테스트 추가
4. 앱 UI 국제화 (현재 분석 응답 언어만 선택 가능)
5. 대형 화면 파일을 기능별 위젯으로 점진 분리

자세한 우선순위는 [improvement_plan.md](improvement_plan.md)를 참고하세요.
