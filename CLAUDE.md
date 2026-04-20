# PlanRoutine (플랜루틴)

## 프로젝트 개요
**PlanRoutine** — 계획(Plan)과 반복(Routine), 교사용 일정 관리 앱.
매년 반복되는 교사 업무 일정을 작년 데이터 기반으로 올해 일정을 빠르게 세팅.
초등학교 교사의 업무 특성상 매년 비슷한 사이클이 반복되므로, 작년 데이터를 기준으로 올해 일정을 검토·확정하는 흐름.

## 핵심 기능
1. **작년 일정 가져오기** — CSV 업로드로 작년 업무 일정 등록 (생산문서등록대장). 플랜루틴 자체 포맷 CSV로 재임포트 시 확정 상태로 즉시 복원.
2. **검토 후 확정** — 가져온 일정을 일정 탭에서 슬라이드로 확정(→) / 삭제(←). 확정 시 캘린더에 자동 등록.
3. **자체 캘린더** — 앱 내 이벤트 CRUD, 양방향 스와이프로 Google 저장(→) / 완료(←).
4. **휴지통** — 일정/이벤트 soft-delete, 30일 후 자동 영구 삭제.
5. **내보내기** — 확정된 일정을 UTF-8 BOM CSV로 공유시트에 전달.
6. **Google 캘린더 연동** — 단방향(앱 → Google) 이벤트 저장.
7. **로컬 알림** — 월초 · 1주 전 · 1일 전 08:00 알림 (timeSensitive).

## 타깃 사용자
- 매년 비슷한 업무 사이클을 가진 초등 교사

## 기술 스택

| 레이어 | 기술 | 비고 |
|--------|------|------|
| 앱 | Flutter 3.x (Dart) | iOS 배포 중. Android는 코드는 있으나 미검증 |
| 상태 관리 | Riverpod | 다른 라이브러리 사용 금지 |
| 라우팅 | GoRouter | ShellRoute + 3탭 (캘린더/일정/설정) |
| 로컬 DB | sqflite | 스키마 v3 (3 테이블, soft-delete + completed) |
| 모델 | Freezed + json_serializable | 불변 객체 |
| CSV 파싱 | csv + charset_converter | EUC-KR/UTF-8 BOM 자동 감지 |
| 파일 선택 | file_picker | |
| 공유 | share_plus, path_provider | 임시 디렉토리 + 공유시트 |
| 앱 정보 | package_info_plus | 설정 탭 버전 표시 |
| 영구 설정 | shared_preferences | 알림 설정, 힌트 바 dismiss |
| 구글 | google_sign_in 6.x + googleapis 13.x + http | 단방향 Calendar API |
| 알림 | flutter_local_notifications + timezone | 로컬 TZ 예약, timeSensitive |
| 날짜 | intl | 한국어 로케일 |
| 테스트 | flutter_test, integration_test, sqflite_common_ffi | 107 유닛 + 10 통합 |

## 프로젝트 구조 (2026-04 기준)

```
planroutine/
├── CLAUDE.md
├── lib/
│   ├── main.dart                   # 시작 시 휴지통 purge + 알림 init/sync
│   ├── app.dart
│   ├── core/
│   │   ├── constants/              # app_strings, app_colors, app_sizes
│   │   ├── theme/                  # app_theme
│   │   ├── router/                 # GoRouter (3탭 + /trash 푸시)
│   │   ├── database/               # DatabaseHelper (v3, forTesting 생성자)
│   │   └── utils/                  # date_utils (formatDate)
│   ├── features/
│   │   ├── import/                 # CSV 가져오기
│   │   │   ├── data/               # csv_parser (parseWithMetadata), import_repository
│   │   │   ├── domain/             # imported_schedule
│   │   │   └── presentation/       # ImportSection(설정 탭 인라인), providers
│   │   ├── schedule/               # 일정 검토/확정
│   │   │   ├── data/               # schedule_repository (soft-delete + purge)
│   │   │   ├── domain/             # schedule (status: pending/confirmed)
│   │   │   └── presentation/       # ScheduleScreen, SlideHintBar, ScheduleEditSheet
│   │   ├── calendar/               # 자체 캘린더
│   │   │   ├── data/               # calendar_repository (soft-delete + completed + purge)
│   │   │   ├── domain/             # calendar_event (deletedAt/completedAt + isCompleted)
│   │   │   └── presentation/       # CalendarScreen, CalendarSlideHintBar,
│   │   │                           # EventEditDialog(2버튼+휴지통),
│   │   │                           # EventListSection(양방향 스와이프)
│   │   ├── trash/                  # 휴지통
│   │   │   └── presentation/       # TrashScreen + TrashSnapshot 프로바이더
│   │   ├── settings/               # 설정 탭
│   │   │   ├── data/               # app_reset_repository, schedule_csv_exporter
│   │   │   └── presentation/       # SettingsScreen (import 인라인, Google 계정,
│   │   │                           # 알림, 휴지통, 데이터 관리, 앱 정보)
│   │   ├── google/                 # Google Calendar 연동
│   │   │   ├── data/               # google_calendar_service
│   │   │   └── presentation/       # google_providers
│   │   └── notifications/          # 로컬 알림
│   │       ├── data/               # notification_service (Darwin/FFI 래퍼),
│   │       │                       # notification_rules (computeNotifications 순수 함수)
│   │       ├── domain/             # notification_settings, pending_notification
│   │       └── presentation/       # notification_providers (syncer + 설정)
│   └── shared/
│       └── widgets/                # main_shell (하단 3탭)
├── ios/
│   ├── Runner/Info.plist           # GIDClientID, CFBundleURLTypes(REVERSED_CLIENT_ID)
│   ├── fastlane/Fastfile           # beta 레인 (App Store Connect API)
│   └── ...
├── data/sample/                    # 테스트용 CSV
├── docs/                           # requirements, data-schema
└── test/
    ├── features/                   # 단위 테스트 (107개)
    │   ├── calendar/data/          # repository 유닛(14)
    │   ├── schedule/data/          # repository 유닛(17)
    │   ├── notifications/          # computeNotifications(15)
    │   ├── import/                 # parser + domain
    │   └── schedule/domain/        # Schedule 모델
    └── helpers/test_database.dart  # FFI in-memory DB 팩토리
integration_test/
└── app_test.dart                   # UX E2E 10 시나리오
```

## 데이터베이스 스키마 (v3)

### schedules
- `id`, `title`, `description`, `scheduled_date`
- `category`, `sub_category`, `source_id` → imported_schedules
- `status` (pending/confirmed)
- `created_at`, `updated_at`, **`deleted_at`** (NULL=활성)

### calendar_events
- `id`, `title`, `description`, `event_date`, `end_date`, `is_all_day`, `color`
- `schedule_id` → schedules
- `created_at`, `updated_at`
- **`deleted_at`** (v2): NULL=활성, ISO=휴지통
- **`completed_at`** (v3): NULL=미완료, ISO=완료 시각

### imported_schedules
- 원본 생산문서등록대장 CSV 보관. PlanRoutine export 포맷 임포트는 이 테이블을 건너뛰고 schedules로 직접 삽입.

### 마이그레이션
- `DatabaseHelper._onUpgrade`: v1→v2(deleted_at), v2→v3(completed_at).
  기존 사용자도 ALTER TABLE로 데이터 유지한 채 업그레이드.

## 주요 설계 결정

### Soft-delete
- 삭제는 `UPDATE deleted_at = NOW()`. 활성 쿼리는 `WHERE deleted_at IS NULL` 필수.
- `getDeletedX` / `restoreX` / `permanentDeleteX` / `purgeOlderThan` API.
- 앱 시작 시 30일 초과 항목 자동 영구 삭제 (main.dart).

### 중복 체크
- `createFromImported` / `insertConfirmedOrPending` / `createFromSchedule` 모두 `deleted_at IS NULL` 기준.
  즉 휴지통에 같은 항목 있어도 재생성 허용.

### 알림
- `computeNotifications(events, settings, now)`는 **순수 함수** — DB/플랫폼 무관, 유닛 테스트 용이.
- `NotificationSyncer.sync()`는 이 결과를 `NotificationService.replaceAll()`로 플랫폼에 반영.
- 이벤트 CRUD(addEvent/updateEvent/deleteEvent/toggleCompleted) + 앱 시작 + 설정 변경 시 자동 sync.
- iOS 64개 상한 → 60개 cap + 가까운 시각 우선 정렬.
- 기본 08:00 발송 (교사 수업 시작 전 여유 확보).
- `InterruptionLevel.timeSensitive` 플래그 지정. 실제 집중 모드 돌파 원하면 Apple Developer Portal에서 capability 활성화 + entitlements 추가 필요.

### Google Calendar 연동
- `google_sign_in`으로 `authHeaders` 획득 → 커스텀 `http.BaseClient`로 `googleapis` 호출.
- 단방향(생성만) — 수정/삭제 동기화 없음 (개인정보 최소 노출).
- GCP OAuth client는 "테스트" 모드, 테스트 사용자 수동 등록 필요. App Store 출시 시 verification 필요.
- Info.plist에 `GIDClientID`와 REVERSED_CLIENT_ID URL scheme 박혀있음.

### 스와이프 UX
| 탭 | 오른쪽(→) | 왼쪽(←) |
|---|---|---|
| 일정 | 확정 | 삭제(soft) |
| 캘린더 | Google 저장 | 완료 토글 |
- 각 탭 상단에 2줄 안내 바 (SharedPreferences로 영구 닫기 가능).

### CSV 라운드트립
- **내보내기**: `schedules`의 확정(`status=confirmed`)만. 컬럼: 제목/등록일자/카테고리/설명/상태. UTF-8 BOM.
- **가져오기 감지**: 헤더에 "상태" 컬럼 있으면 PlanRoutine export로 인식 → imported_schedules 건너뛰고 schedules에 직접 insert + 캘린더 이벤트 자동 생성.
- 원본 생산문서등록대장 CSV는 기존 흐름 유지(imported_schedules → 전체 등록 버튼 → pending).

## 배포

### fastlane (`ios/fastlane/Fastfile`)
- `beta` 레인 — `flutter build ipa --release --build-number=N` + App Store Connect API 업로드.
- build_number는 `latest_testflight_build_number + 1`.

### 알려진 빌드 이슈
- 통합 테스트(simulator 빌드) 직후 바로 release 빌드하면 **simulator slice가 framework에 남아** altool 업로드 거부(91169).
- 해결: `flutter clean && rm -rf ios/Pods ios/Podfile.lock ios/build && flutter pub get && pod install && flutter build ipa`.
- fastlane Ruby(4.0.1) vs 시스템 Ruby(2.6) 충돌로 fastlane이 CocoaPods를 못 찾는 경우 → 수동 `flutter build ipa`로 IPA 생성 후 `xcrun altool --upload-app`로 직접 업로드.

## 샘플 데이터
- `data/sample/2025_생산문서등록대장.csv` — 실제 2025년 생산문서 65건
  - 핵심 컬럼: 등록일자, 제목, 과제명, 과제카드명, 결재유형
  - 업무 분류: 일과운영관리(28), 교육과정계획(10), 조직통계(7), 학생학적(4)

## 코딩 규칙
- Feature-first 구조: `lib/features/{기능}/data|domain|presentation/`
- Riverpod Provider: `presentation/providers/`에 배치
- Freezed 모델: 모든 도메인 모델에 `@freezed` 사용
- Null safety: `!` 강제 언래핑 금지
- 하드코딩 금지: 문자열→app_strings, 색상→app_colors, 크기→app_sizes
- 파일명: snake_case / 클래스명: PascalCase
- 한글 UI, 한글 주석
- 삭제 시 반드시 `deleted_at IS NULL` 필터 동반
- 날짜 문자열 포맷은 `date_utils.formatDate(DateTime) → 'YYYY-MM-DD'` 공용 함수 사용
