# 플랜루틴 — 다음에 할 일 (resume 가이드)

마지막 작업: **2026-04-20 v29 배포 후 세션 정리**
상태: **Phase 1~4 완료, 유닛 107/107 · 통합 11/11 통과**

## 현재까지 배포 이력

| 버전 | 주요 변경 |
|---|---|
| v9 (초기) | 4개 기본 탭 + CSV 가져오기 |
| v10 (Phase 1) | 탭 재구성(설정), 스낵바 UX, 중복 확정 버그 |
| v11~14 | 가져오기 인라인, 스낵바 버그 수정 |
| v15~16 (Phase 2) | 휴지통 · soft-delete · 캘린더 슬라이드 삭제 · 확정 뱃지 |
| v17~19 (Phase 3A) | CSV export · 앱 버전 정보 |
| v20~22 (Phase 3B) | 구글 캘린더 연동 · CSV round-trip |
| v23~24 | 이벤트 완료 토글 + 리팩토링 |
| v25~26 (Phase 4) | 로컬 알림 (월초/1주/1일 전, 08:00) |
| v27~28 | 편집 시트 단순화(2버튼+휴지통) · 양방향 스와이프 · timeSensitive 알림 · 캘린더 안내바 |
| v29 | CLAUDE.md 갱신 · 통합 테스트 보강 (배포 없음) |

---

## 🚀 다음에 바로 할 수 있는 작업

### A. App Store 출시 준비 (덩치 큼, 실제 릴리스 목표)

1. **앱 아이콘 교체** ⚠️ 심사 필수
   - 현재 Flutter 기본 아이콘(파란 F). `flutter_launcher_icons` 패키지로 1024×1024 원본 → 자동 생성
   - 달력+체크 조합 or 플래너 모티프
2. **개인정보 처리방침 URL**
   - GitHub Pages에 단일 md 호스팅 (무료, 30분)
   - 포함 내용: 수집 데이터(로컬 only + Google Calendar 접근 권한), 연락처
3. **Google OAuth verification**
   - GCP 콘솔에서 제출. 필요: 개인정보 처리방침 URL + 앱 데모 영상
   - 심사 2~6주
4. **App Store 심사 자료**
   - 앱 설명 (한/영), 키워드, 카테고리
   - 스크린샷 6.7"/6.5" 각 5장 (XcodeScreenshot 또는 기기 캡쳐)
   - 심사 거부 사유 대비: 데이터 삭제 기능 명시(휴지통 + 전체 초기화 있음)
5. **iOS entitlements 추가** (선택, timeSensitive 활성화)
   - `ios/Runner/Runner.entitlements` 생성 + `com.apple.developer.usernotifications.time-sensitive = true`
   - Apple Developer Portal에서 App ID capability 활성화
   - Xcode 프로젝트에 entitlements 연결

### B. 기능 개선 (출시 전 또는 후)

6. **알림 시각 피커** (작은 기능)
   - 현재 08:00 고정. 설정 탭에 TimePicker 추가
   - `NotificationSettings.hour/minute` 이미 존재하므로 UI만
7. **구글 캘린더 중복 방지**
   - 현재 같은 이벤트를 여러 번 "Google 저장" 스와이프하면 중복 생성
   - `calendar_events.google_event_id` 컬럼 추가 → 첫 번째 저장 후 기록, 재저장 시 update
8. **Android 지원 결정**
   - 현재 Android는 코드만 있고 미검증. 포기/지원 명시 필요
   - 포기: `flutter config --no-enable-android` + pubspec 정리
   - 지원: google_sign_in 안드로이드 설정 + 알림 아이콘 + 빌드 테스트
9. **Google 연결 해제 시 로컬 미변경 동작 확인**
   - 현재 구현: `signOut()`만 부름. 구글에 저장된 이벤트는 그대로 남음 (의도된 동작이지만 명시적 문서 필요)

### C. 기술 부채 / 품질

10. **Provider 테스트 추가** (선택)
    - 현재 유닛 테스트는 Repository + 순수 함수 위주
    - `NotificationSettingsNotifier` / `TrashNotifier` 등 Provider 레이어 테스트 가능
    - 우선순위 낮음 (통합 테스트가 커버)
11. **"알림 디버그 뷰"** (개발자/사용자 공용)
    - 설정 탭 > 알림 섹션에 "예약된 알림 N개 보기" 추가
    - `flutter_local_notifications.pendingNotificationRequests()` 사용
    - 신뢰도 + 디버깅 양쪽에 도움

---

## 🔍 미해결/확인 필요 항목

### 실기 장기 테스트 미완료
- **알림이 실제로 다음날 08:00에 오는지** 검증 미확인 (v26 배포 후 레벨 1 테스트만 했음)
- 확인 방법: 오늘 내일 날짜 이벤트 추가 → 다음날 08:00 대기 → 배너 확인
- 안 오면: `NotificationService.init()` 실패, 시계 조작, 권한 문제 중 하나 의심

### iOS 16+ 집중 모드 동작 검증 미완료
- `timeSensitive` 플래그만 지정했으나 entitlement 없어 현재는 silent 무시
- 집중 모드에서 알림이 뚫리는지 확인하려면 entitlement 작업 필요

### Google OAuth "테스트 사용자" 제한
- 현재 `bery97@gmail.com` 외 다른 이메일로 로그인 시 "미확인 앱" 경고 + 차단
- 타인 배포 전 verification 필수

---

## 📁 핵심 파일 위치 (resume 시 참고)

```
lib/core/database/database_helper.dart   # DB 스키마 v3, 마이그레이션
lib/core/utils/date_utils.dart           # formatDate 공용 함수
lib/features/notifications/              # 알림 시스템 (핵심 로직은 notification_rules.dart 순수 함수)
lib/features/trash/                      # 휴지통 화면 + 프로바이더
lib/features/settings/presentation/screens/settings_screen.dart  # 가장 큰 UI 파일, 설정 탭 전체
lib/features/calendar/presentation/widgets/event_edit_dialog.dart  # 2버튼 + 휴지통 구조
lib/features/calendar/presentation/widgets/event_list_section.dart  # 양방향 스와이프 Dismissible
CLAUDE.md                                # 전체 아키텍처 가이드 (v29 갱신)
integration_test/app_test.dart           # UX E2E 11 시나리오
```

---

## 💡 추천 진행 순서 (내 의견)

**만약 App Store 출시가 목표면:**
1. 앱 아이콘 교체 (1~2시간)
2. 개인정보 처리방침 URL (30분)
3. entitlements + timeSensitive 완전 활성화 (1시간)
4. 스크린샷 + 앱 설명 작성 (2시간)
5. Google OAuth verification 제출 (제출 후 2~6주 대기)
6. App Store 심사 제출 (병렬 진행 가능)

**만약 기능 확장이 목표면:**
1. 알림 시각 피커 (30분, 빠른 UX 개선)
2. 구글 캘린더 중복 방지 (1~2시간)
3. 안드로이드 지원 결정

**만약 확신 검증이 목표면:**
1. v28 알림 장기 테스트 (다음날 08:00 체크)
2. TestFlight에 다른 테스터(동료 선생님) 초대해 피드백 수집
3. 발견된 이슈 기반 v30+ 개선

---

## 이어가려면 LLM에게 이렇게 전달

> "플랜루틴 프로젝트 이어서. `docs/next_steps.md` 읽고 현재 상태 파악해줘. 그 다음 [A-1 앱 아이콘 / B-6 알림 시각 피커 / ...] 작업 시작해보자."
