# PlanRoutine (공직플랜)

## 프로젝트 개요
**공직플랜** — 계획(Plan)과 반복(Routine). 초등 교사를 위한 업무 일정 관리 앱.
매년 반복되는 교사 업무 사이클을 작년 데이터 기반으로 올해 일정으로 빠르게 세팅.
작년 CSV를 가져와 일정 탭에서 검토·확정하는 흐름이 핵심.

## 핵심 기능
1. **작년 일정 가져오기** — 설정 탭 1줄 진입 → `/import` 풀스크린 플로우에서 CSV 업로드. 플랜루틴 자체 포맷 CSV는 재임포트 시 확정 상태로 즉시 복원.
2. **검토 후 확정** — 일정 탭에서 슬라이드로 확정(→) / 삭제(←). 진행도 행 우측의 `전체 확정` pill로 일괄 확정. 확정 시 캘린더 이벤트 자동 생성.
3. **자체 캘린더** — 앱 내 이벤트 CRUD, 양방향 스와이프 (→ Google 저장 / ← 완료 토글). 제목에 올해 이전 연도가 있는 이벤트는 리스트에 "이전 연도 자료" 골드 배지(`2025→2026`) 노출 → 탭 시 연도 고친 제목으로 편집 화면 진입(날짜도 함께 수정). 편집 다이얼로그 내에도 동일 연도 바꾸기 칩.
4. **휴지통** — 일정/이벤트 soft-delete, 30일 후 자동 영구 삭제.
5. **내보내기** — 확정된 일정을 UTF-8 BOM CSV로 공유시트에 전달.
6. **Google 캘린더 연동** — 단방향(앱 → Google) 이벤트 저장, `google_event_id`로 중복 방지.
7. **로컬 알림** — 이번 주(월요일) · 당일 아침 08:00 알림 (timeSensitive).
8. **오늘 탭(첫 화면)** — 오늘 처리할 이벤트만 모아 체크 원 탭으로 완료. 완료 순간 골드
   도장이 찍히고 상단 결산 링이 차오른다. 기한이 지난 항목은 롤링 7일까지만 기본 접힘.

## 타깃 사용자
- 매년 비슷한 업무 사이클을 가진 초등 교사

## 기술 스택

| 레이어 | 기술 | 비고 |
|--------|------|------|
| 앱 | Flutter 3.x (Dart) | iOS 배포 중. Android는 코드는 있으나 미검증 |
| 상태 관리 | Riverpod | 다른 라이브러리 사용 금지 |
| 라우팅 | GoRouter | ShellRoute 4탭 (오늘/캘린더/검토/설정) + push(/trash, /import). 초기 라우트 `/today` |
| 로컬 DB | sqflite | 스키마 v4 (3 테이블, soft-delete + completed + google_event_id) |
| 모델 | Freezed + json_serializable | 불변 객체 |
| CSV 파싱 | csv + charset_converter | EUC-KR/UTF-8 BOM 자동 감지 |
| 파일 선택 | file_picker | |
| 공유 | share_plus, path_provider | 임시 디렉토리 + 공유시트 |
| 앱 정보 | package_info_plus | 설정 탭 버전 표시 |
| 영구 설정 | shared_preferences | 알림 설정, 힌트 바 dismiss, 화면 테마, 완료 도장 |
| 구글 | google_sign_in 6.x + googleapis 13.x + http | 단방향 Calendar API |
| 알림 | flutter_local_notifications + timezone | 로컬 TZ 예약, timeSensitive |
| 날짜 | intl | 한국어 로케일 |
| 테스트 | flutter_test, integration_test, sqflite_common_ffi | 360 유닛/위젯 + 11 통합 |

## 프로젝트 구조

```
planroutine/
├── CLAUDE.md
├── lib/
│   ├── main.dart                       # 시작 시 휴지통 purge + 알림 init/sync + onboarding 체크
│   ├── app.dart                        # GoRouter 보관 + planroutine/shared_file 채널 listener
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_strings.dart        # 공통 상수 + barrel export
│   │   │   ├── app_colors.dart
│   │   │   ├── app_sizes.dart
│   │   │   └── strings/                # 도메인별 Strings 클래스
│   │   │       ├── calendar_strings.dart
│   │   │       ├── google_strings.dart
│   │   │       ├── import_strings.dart
│   │   │       ├── notification_strings.dart
│   │   │       ├── schedule_strings.dart
│   │   │       ├── settings_strings.dart
│   │   │       ├── today_strings.dart
│   │   │       └── trash_strings.dart
│   │   ├── theme/                      # app_theme, app_gradients, app_text_styles
│   │   ├── router/                     # GoRouter (4탭 + /trash, /import 푸시)
│   │   ├── database/                   # DatabaseHelper (v4, forTesting 생성자)
│   │   └── utils/                      # date_utils (formatDate)
│   ├── features/
│   │   ├── import/                     # 작년 CSV 가져오기
│   │   │   ├── data/                   # csv_parser, import_repository
│   │   │   ├── domain/                 # imported_schedule
│   │   │   └── presentation/
│   │   │       ├── screens/import_screen.dart  # 풀스크린 + sticky 스테퍼
│   │   │       ├── widgets/
│   │   │       │   ├── import_summary_card.dart
│   │   │       │   └── edufine_guide_section.dart  # 2단 접힘 안내 + 팁 박스
│   │   │       └── providers/                   # importStateProvider (importFromPath API)
│   │   ├── schedule/                   # 일정 검토/확정
│   │   │   ├── data/                   # schedule_repository (soft-delete + purge)
│   │   │   ├── domain/                 # schedule (status: pending/confirmed)
│   │   │   └── presentation/           # ScheduleScreen, SlideHintBar, EditSheet
│   │   ├── calendar/                   # 자체 캘린더
│   │   │   ├── data/                   # calendar_repository
│   │   │   ├── domain/                 # calendar_event (deletedAt/completedAt)
│   │   │   └── presentation/           # CalendarScreen, EventEditDialog, ListSection
│   │   ├── trash/                      # 휴지통
│   │   │   └── presentation/           # TrashScreen + snapshot
│   │   ├── settings/                   # 설정 탭 (섹션별 위젯 분리)
│   │   │   ├── data/                   # app_reset_repository, schedule_csv_exporter
│   │   │   └── presentation/
│   │   │       ├── screens/settings_screen.dart   # 얇은 조합
│   │   │       ├── widgets/
│   │   │       │   ├── settings_section.dart       # 헤더+본문+Divider wrapper
│   │   │       │   ├── import_list_tile.dart
│   │   │       │   ├── export_list_tile.dart
│   │   │       │   ├── google_account_list_tile.dart
│   │   │       │   ├── notification_settings_tiles.dart
│   │   │       │   ├── stamp_settings_tiles.dart   # 완료 도장 모양 + 흐리게
│   │   │       │   ├── trash_list_tile.dart
│   │   │       │   ├── reset_list_tile.dart
│   │   │       │   └── app_info_list_tile.dart
│   │   │       └── providers/
│   │   ├── google/                     # Google Calendar 연동
│   │   │   ├── data/                   # google_calendar_service
│   │   │   └── presentation/           # google_providers
│   │   ├── notifications/              # 로컬 알림
│   │   │   ├── data/                   # notification_service, notification_rules
│   │   │   ├── domain/                 # notification_settings, pending_notification
│   │   │   └── presentation/           # syncer + 설정 providers
│   │   ├── today/                      # 오늘 탭 (첫 화면)
│   │   │   ├── domain/                 # today_view(순수 함수), stamp_settings(도장 설정)
│   │   │   └── presentation/
│   │   │       ├── screens/today_screen.dart    # provider 배선만
│   │   │       ├── providers/today_providers.dart
│   │   │       └── widgets/
│   │   │           ├── midnight_watcher.dart    # 자정 넘김 시 기준일 갱신 (app.dart가 감쌈)
│   │   │           ├── today_body.dart          # 순수 위젯 (위젯 테스트 대상)
│   │   │           ├── today_event_row.dart     # 체크 원 + 제목 + 도장 슬롯
│   │   │           ├── today_progress_ring.dart # 결산 링 (CustomPainter)
│   │   │           └── completion_seal.dart     # 완료 도장 (3종)
│   │   └── onboarding/                 # 최초 진입 플로우
│   └── shared/
│       └── widgets/
│           ├── main_shell.dart         # 하단 탭 Shell
│           ├── floating_tab_bar.dart   # 이름은 legacy, 현재 화면 폭 불투명 탭바
│           ├── gold_fab.dart           # 골드 원형 FAB (캘린더·오늘 탭 공유)
│           ├── brand_logo.dart         # LogoHybrid 디자인 (CustomPainter)
│           ├── gold_gradient_button.dart  # 좌우 padding 24, 중앙 정렬용 Center 래핑
│           ├── section_header.dart     # title + optional subtitle
│           └── confirm_dialog.dart     # 2-버튼 확인 다이얼로그 공통
├── ios/
│   ├── Runner/
│   │   ├── Info.plist                  # GIDClientID, REVERSED_CLIENT_ID, CFBundleDocumentTypes(CSV)
│   │   ├── AppDelegate.swift           # application(_:open:options:) → planroutine/shared_file 채널
│   │   └── SceneDelegate.swift         # scene URL → AppDelegate 포워딩
│   ├── fastlane/Fastfile               # beta/release 레인 (IPA glob: Dir.entries)
│   ├── Gemfile (+ Gemfile.lock)        # fastlane + cocoapods 동일 Ruby 환경
│   └── bin/fastlane.sh                 # Homebrew Ruby 경로 주입 wrapper
├── assets/
│   ├── icon/app_icon.png               # 1024x1024 원본 (test/tools/gen_app_icon.dart로 재생성)
│   ├── images/edufine_csv_guide.png    # Import 가이드 annotation 스크린샷
│   └── fonts/                          # Pretendard Variable
├── data/sample/                        # 테스트용 CSV
├── docs/                               # requirements, data-schema
├── test/
│   ├── features/                       # 단위 테스트 (109개)
│   │   ├── calendar/data/
│   │   ├── schedule/data/
│   │   ├── notifications/              # computeNotifications
│   │   ├── import/                     # parser + domain
│   │   └── schedule/domain/
│   ├── helpers/test_database.dart      # FFI in-memory DB 팩토리
│   └── tools/gen_app_icon.dart         # 1024×1024 PNG 렌더 (자동 스캔 제외)
└── integration_test/
    └── app_test.dart                   # UX E2E 11 시나리오
```

## 데이터베이스 스키마 (v4)

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
- **`google_event_id`** (v4): NULL=미저장, 값 있으면 재저장 시 update (중복 방지)

### imported_schedules
- 원본 생산문서등록대장 CSV 보관. PlanRoutine export 포맷 임포트는 이 테이블을 건너뛰고 schedules로 직접 삽입.

### 마이그레이션
- `DatabaseHelper._onUpgrade`: v1→v2(deleted_at), v2→v3(completed_at), v3→v4(google_event_id).
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
- 이벤트 CRUD + 앱 시작 + 설정 변경 시 자동 sync.
- iOS 64개 상한 → 60개 cap + 가까운 시각 우선 정렬.
- 기본 08:00 발송 (교사 수업 시작 전 여유 확보).
- `InterruptionLevel.timeSensitive` 플래그 지정. 실제 집중 모드 돌파 원하면 Apple Developer Portal에서 capability 활성화 + entitlements 추가 필요.
- 설정 화면에서는 마스터 스위치 하나만 노출 + 현재 설정 요약(`08:00 · 이번 주·당일`) subtitle. 이번 주/당일 아침/알림 시각/테스트/예약된 알림 보기는 `고급` ExpansionTile 안에 접힘.

### 오늘 탭 (결재 도장 + 결산 링)
- **DB 변경 없음.** `calendar_events.completed_at`과 기존 `getEventsByDateRange`를 재사용한다.
- `buildTodayView(events, today, lookbackDays)`는 **순수 함수** — 지난/오늘 분리, 정렬,
  진행도 계산을 한곳에 모아 유닛 테스트로 고정한다(`computeNotifications`와 같은 패턴).
- **지난 항목은 롤링 7일 컷오프 + 기본 접힘.** 작년 CSV를 임포트하는 앱이라 컷오프가 없으면
  지난 미완료가 수백 건 쌓여 "오늘"이 화면 밖으로 밀려난다.
- **진행도 링은 오늘 항목만** 계산한다. 지난 항목이 섞이면 1.0(완주)에 도달할 수 없다.
- **완료 토글은 자리 고정** — `TodayView.withToggled()`로 해당 항목만 교체하고
  `invalidateSelf`를 하지 않는다. 즉시 재정렬하면 탭한 행이 밀려나 도장 애니메이션이
  화면 밖에서 재생된다.
- **`eventsRevisionProvider`**(calendar_providers): 이벤트 CRUD가 올리는 신호. 오늘 탭이
  watch해 스스로 재조회한다. 캘린더 provider가 오늘 탭 provider를 직접 invalidate하면
  feature 간 순환 참조가 되므로 신호만 올린다. **단 `TodayViewNotifier.toggleCompleted`는
  리비전을 올리지 않는다** — 올리면 자기 build가 다시 돌아 자리 고정이 깨진다.
- **`todayViewProvider`는 autoDispose.** 이 앱은 `StatefulShellRoute`가 아닌 평범한
  `ShellRoute`라 `context.go`로 탭을 옮기면 화면이 dispose된다. provider만 살아남으면
  재진입해도 옛 목록이 보인다 → 수명을 화면에 묶어 재진입 = 재조회로 만든다.
  - ⚠️ **`push`는 예외다.** `push`로 덮인 화면은 offstage로 마운트가 유지돼 autoDispose가
    걸리지 않는다. 지금은 `/trash`·`/import` 진입점이 설정 탭에만 있어 무해하지만,
    **오늘 탭에 push 라우트를 붙이면** 그 화면이 `eventsRevisionProvider`를 올리지 않는 한
    pop 후 목록이 stale이 된다.
- **자정 넘김**: `todayReferenceProvider`는 부팅 시점 `DateTime.now()`를 캐시하고 autoDispose가
  아니라 탭을 옮겨도 살아 있다. `MidnightWatcher`(`app.dart`가 `MaterialApp`을 감쌈)가 앱 복귀 시
  날짜가 **바뀐 경우에만** 무효화한다(복귀마다 하면 같은 날에도 DB 재조회). FAB은 캐시된
  기준일이 아니라 누른 시점의 `DateTime.now()`로 일정을 만든다 — 자정 직후 어제 날짜로
  등록되는 것을 막는다. 포그라운드로 켜둔 채 자정을 넘기는 경우는 미대응(복귀 이벤트가 없다).
- **완료 취소는 낙하의 역재생이 아니라 제자리 페이드아웃**이다. 같은 곡선을 reverse하면
  사라지는 동안 도장이 `scale 2.4` 쪽으로 부풀어 슬롯(56)을 넘어 제목을 덮는다
  (`CompletionSeal`이 `AnimationStatus.reverse`를 보고 scale/rotate를 안착값에 고정).
- **완료 도장**(`설정 > 완료 도장`): 모양 3종(완료 원형·결재 사각·좋아요 엄지 아이콘) +
  "이미 찍은 도장 흐리게"(기본 ON). 모양 규칙은 `SealStyle` enum이 들고 있어(`isSquare`,
  `usesIcon`) 위젯은 enum만 보고 그린다. 흐리게는 **지난 도장에만** 적용 —
  `TodayEventRow._stampedOnEntry`로 구분하고 방금 누른 도장은 진하게 남긴다.
  도장 문구는 44px 안에 들어가야 한다(내부 폭 31.4). 영문 4글자('Good')는 13px에서 50px로
  물리적으로 안 맞아 아이콘을 쓴다 — 가드 테스트가 이 폭을 지킨다.

### Google Calendar 연동
- `google_sign_in`으로 `authHeaders` 획득 → 커스텀 `http.BaseClient`로 `googleapis` 호출.
- 단방향(생성만) — 수정/삭제 동기화 없음 (개인정보 최소 노출).
- GCP OAuth client는 "테스트" 모드, 테스트 사용자 수동 등록 필요. App Store 출시 시 verification 필요.

### 캘린더 그리드 가시성
- **주말 열 배경**: 토·일 열에 옅은 tint(`calendarWeekendTint`/`calendarSaturdayTint`)를
  **요일 헤더부터 마지막 주까지 세로로** 깐다. 셀마다 그리면 radius로 열이 끊기고 헤더까지
  이어지지 않으므로, `CalendarGrid`가 `Stack`으로 그리드 뒤에 한 장을 깐다.
  - ⚠️ `Stack`을 **`Align(alignment: Alignment.topCenter)`** 로 감싸 부모의 tight 제약을
    풀어야 한다. 부모 `CalendarMonthPager`가 6행 기준 고정 높이를 주는데, 5행인 달은
    그리드가 더 짧아 `Positioned.fill`이 빈 주 자리까지 칠해 열이 아래로 샌다
    (테스트가 지킨다). 셀·pager 높이는 `AppSizes.calendarCellHeight`에서 파생된다 —
    두 곳에 숫자를 박으면 셀을 키울 때 pager가 실제 주를 자른다.
- **토요일은 중립 파랑**(`calendarSaturday`: 다크 `#8BA8D4` / 라이트 `#3F5F94`).
  골드는 **오늘 셀·선택 링·중요 ★** 강조 전용이다. 토요일까지 골드로 쓰면 골드가 네 가지
  의미를 동시에 져서 어느 것도 강조가 안 된다.
- **요일 헤더는 본문색 + w700** — 라벨(요일)이 데이터(날짜 `14px w500`)보다 옅으면 배경처럼
  묻힌다. 높이는 그대로 두고 굵기·색으로만 위계를 만든다.
- 이벤트 점은 최대 3개까지만 표기(4개 이상도 3개로 유지).

### 스와이프 UX
| 탭 | 오른쪽(→) | 왼쪽(←) |
|---|---|---|
| 일정 | 확정 | 삭제(soft) |
| 캘린더 | Google 저장 | 완료 토글 |
- 각 탭 상단에 2줄 안내 바 (SharedPreferences로 영구 닫기 가능).

### 제목 연도 바꾸기
- 임포트는 날짜(scheduled_date)만 올해로 변환하고 **제목 문자열의 연도는 원본 유지**(의도적). 그래서 "2025학년도 …" 제목이 남는다.
- `core/utils/title_year_utils.dart`의 순수 함수 `bumpTitleYear(title, currentYear)`가 치환 담당. 정규식 `(?<!\d)20\d\d(?!\d)`로 4자리 연도만 매칭(문서번호·"1000명" 등 비연도 차단), **올해보다 작은 연도만** 올해로 치환하고 **올해 이상(이미 미래 참조) 연도는 보존**. 감지된 가장 이른 옛 연도를 함께 반환.
- 노출 지점 2곳(둘 다 같은 순수 함수 공유): ① 캘린더 리스트의 "이전 연도 자료" 골드 배지 → 탭 시 연도 고친 제목으로 `EventEditDialog` 진입(날짜 등 마저 수정) ② `EventEditDialog` 제목 아래 실시간 칩(입력 중 옛 연도 감지 시 노출).

### CSV 라운드트립
- **내보내기**: `schedules`의 확정(`status=confirmed`)만. 컬럼: 제목/등록일자/카테고리/설명/상태. UTF-8 BOM.
- **가져오기 감지**: 헤더에 "상태" 컬럼 있으면 PlanRoutine export로 인식 → imported_schedules 건너뛰고 schedules에 직접 insert + 캘린더 이벤트 자동 생성.
- 원본 생산문서등록대장 CSV는 기존 흐름 유지(imported_schedules → 전체 등록 버튼 → pending).

### 설정 탭 구조
- `settings_screen.dart`는 100줄 미만의 얇은 조합. 각 섹션 UI는 `widgets/*_list_tile.dart`에 분리.
- `SettingsSection` wrapper가 헤더(title+subtitle) + 본문 + Divider 3종 세트를 1줄로 묶는다.
- 확인 다이얼로그는 `shared/widgets/confirm_dialog.dart`의 `ConfirmDialog.show()` 공통 사용.

### Import 플로우
- 설정 탭에 1줄 ListTile만 놓고, 탭 시 `/import`로 push (ShellRoute 내부라 탭바 유지).
- `ImportScreen`의 AppBar 바로 아래에 `ImportSteps` 스테퍼가 sticky로 고정돼, Initial/Loading/Success/Registered 모든 상태에서 현재 단계가 보인다.
- Initial 뷰에 `EdufineGuideSection` 접힘 안내 (① CSV 다운받기: 번호 4단계 + annotation 스크린샷 / ② 아이폰으로 가져오기: A. 공유시트 / B. 파일 앱 택1 + "더 보기" 팁 박스).

### iOS 공유시트 통합 (외부 앱에서 공직플랜으로 열기)
- 카카오톡/메일/파일 앱에서 CSV 파일 공유 → 공유 목록에 "공직플랜" 노출 → 탭하면 Import 화면으로 자동 이동 + 즉시 파싱. 사용자가 "파일 선택" 탭 불필요.
- `Info.plist`의 `CFBundleDocumentTypes` + `LSSupportsOpeningDocumentsInPlace`로 CSV UTI(`public.comma-separated-values-text` 등) 수신 선언. Share Extension은 불필요.
- `AppDelegate.swift`의 `application(_:open:options:)` 표준 iOS hook + 커스텀 `FlutterMethodChannel("planroutine/shared_file")`로 file URL을 Flutter에 전달. `receive_sharing_intent` 플러그인은 Share Extension + App Groups 기반이라 Open-In flow에서 동작 안 함 — native 직접 구현이 더 간결.
- 타이밍: cold-start로 열린 경우 native `pendingPath` 버퍼, Flutter가 `getPending`으로 꺼냄. running 경우는 `onFileShared` push.
- `GoRouter.redirect`에서 `scheme=file`/`.csv` 접미사 URL을 가로채 `/import`로 전환 → "Page Not Found" 방지.
- `SceneDelegate.swift`에서 scene URL 이벤트를 `AppDelegate.application(_:open:options:)`로 포워딩 (iOS 13+ scene lifecycle 대응).

### 문자열 구조
- 도메인에 귀속되는 문자열은 `lib/core/constants/strings/*.dart`의 각 클래스(SettingsStrings·NotificationStrings·GoogleStrings·ImportStrings·ScheduleStrings·CalendarStrings·TrashStrings).
- 공통 문자열(appName·tab*·cancel·save·retry·loading·error·compareYearFormat·categoryDailyOps)만 `AppStrings`에 잔류.
- `app_strings.dart`가 각 domain strings를 barrel export하므로 호출부는 이 파일 하나만 import 하면 된다.

### 로고
- `BrandLogo`(shared/widgets)는 `LogoHybrid` 디자인(수첩 바디 + 달력 그리드). 120×120 viewBox를 `size.width/120` 스케일로 환산.
- 캘린더 AppBar leading(size 28) + 온보딩(size 80)에서 사용.
- iOS 홈 아이콘은 `test/tools/gen_app_icon.dart`가 navy 배경 + 90% LogoHybrid를 1024×1024 PNG로 렌더해 `assets/icon/app_icon.png`에 덮어쓰고, `flutter_launcher_icons`가 각 사이즈를 재생성.

### 탭바
- `shared/widgets/floating_tab_bar.dart`(이름은 과거 플로팅 디자인의 잔재) — 실제로는 화면 폭을 꽉 채운 불투명 바(배경 = 테마 surface색: 다크 navyMid / 라이트 흰색) + 상단 1px 골드 라인. 4탭 = **오늘 / 캘린더 / 검토 / 설정**. `extendBody: false`라 리스트가 탭바 뒤로 비치지 않고 FAB도 Scaffold가 자동으로 바 위에 올려준다.
- 배경색은 `Theme.of(context).colorScheme.surface`를 참조한다 — ShellRoute 탭바는 라우트 전환에 유지(리빌드 안 됨)돼, Theme 의존이 없으면 테마 전환 시 이전 색이 남는다.

### 화면 테마 (다크/라이트)
- 설정 탭 최상단 `ThemeModeTile`(SegmentedButton: 시스템/밝게/어둡게). 선택은 `themeModeProvider`(shared_preferences 저장). 시스템 모드는 기기 밝기 추종.
- **팔레트 전환 구조**: `AppColors`는 `static const`가 아니라 `_Palette`(dark/light 두 인스턴스) 기반 **static getter**. `AppColors.applyBrightness(effective)`로 현재 팔레트를 교체. 313곳 참조부는 무수정, const 컨텍스트만 const 해제. `AppTextStyles`·`AppGradients`도 같은 이유로 getter.
- 다크 = 네이비+골드+크림, 라이트 = **쿨 미스트 화이트**(배경 #F6F8FB, 본문 네이비 #17253D, 딥골드 액센트 #9A7415, 밝은 골드 #E6B95C).
- **골드 의미 토큰**: `gold`(배경 위 텍스트/아이콘/보더 — 라이트에선 대비용 딥골드) / `goldFill`(배지·pill·버튼·오늘 셀 채움 — 밝은 골드) / `onGold`(goldFill 채움 위 네이비 글씨). "골드 채움은 goldFill + onGold" 규칙으로 다크/라이트 대비를 함께 맞춘다.
- **테마 변경 = 전체 재생성**: `app.dart`가 effective brightness로 `AppColors.applyBrightness` + `AppTheme.of(brightness)` 동기화 후, MaterialApp `builder`에서 brightness를 `KeyedSubtree` key로 주어 라우트 하위 전체를 재생성한다(라우터 상태는 상위라 현재 탭 유지). 전역 팔레트가 개별 위젯 리빌드 순서에 의존하지 않게 하는 핵심.

## 배포

### 명령
```
./ios/bin/fastlane.sh beta          # TestFlight (재빌드+업로드)
./ios/bin/fastlane.sh release build:115   # 빌드 승격 + 릴리즈 노트 반영 (제출은 안 함)
./ios/bin/fastlane.sh upload_screenshots  # 스토어 스크린샷 교체
./ios/bin/fastlane.sh check_screenshots   # 올라간 스크린샷 슬롯별 확인
./ios/bin/fastlane.sh dedupe_screenshots  # 중복 업로드 정리
./ios/bin/fastlane.sh withdraw_review     # 심사 철회 (편집 가능 상태로)
./ios/bin/fastlane.sh asc_state           # 심사 단계 + 선택된 빌드 조회
./ios/bin/fastlane.sh check_builds  # 최근 빌드 processing_state 조회 (post-deploy)
```
- Wrapper가 Homebrew Ruby(`/opt/homebrew/opt/ruby/bin`)를 PATH 앞에 주입해 `bundle exec fastlane`을 돌린다. 사용자 shell 설정은 건드리지 않는다.
- `ios/Gemfile`에 fastlane + cocoapods 고정. 최초 실행 시 wrapper가 자동으로 `bundle install`.
- beta의 build_number는 Fastfile이 `latest_testflight_build_number + 1`로 자동 계산.
- **release는 promote 전용 + 제출하지 않는다**: 재빌드/재업로드 없이 TestFlight 빌드를 `skip_binary_upload`로 승격하고, 버전 페이지 생성·릴리즈 노트 주입까지 한다. **최종 '심사를 위해 제출' 버튼은 사람이 ASC에서 누른다** (`submit:true`를 명시하면 자동 제출하지만 기본은 아님). 되돌리기 어려운 외부 작업이라 제출 직전에 눈으로 확인할 여지를 남긴다.
- **승격 대상은 `build:<N>`으로 못박을 것.** 미지정 시 최신을 집는데, 실기기 검증 후 `beta`를 한 번 더 돌렸다면 검증하지 않은 빌드가 올라간다.
- **가드 4개**: A(버전>승인본) / B(빌드 VALID) / D(이미 심사 단계면 손대지 않음) / E(릴리즈 노트 존재). 버전 페이지는 없으면 자동 생성된다(minor·major에서는 항상 없다).
- **릴리즈 노트는 `docs/release_notes/<버전>.ko.txt`** — release가 읽어 ASC에 넣는다. 버전을 올리면 이 파일을 먼저 만든다.
- **beta 레인**은 시작 시 `reset_ios_caches`(flutter clean + Pods/build 제거)를 자동 실행 — 시뮬 슬라이스 함정(#6) 차단. clean 때문에 매 beta가 수 분 더 걸린다. release는 빌드가 없어 해당 없음.

### 배포 플로우 정책 (메모리에 기록됨)
`flutter analyze` + `flutter test` 통과 시 사용자 승인 없이 바로 `./ios/bin/fastlane.sh beta` 실행 후 push까지 진행. 배포 실패 시에만 멈춰서 보고.

### 앱 아이콘 재생성
```
flutter test test/tools/gen_app_icon.dart   # 1024x1024 원본 갱신
dart run flutter_launcher_icons              # 각 iOS 사이즈 재생성
```
- `test/tools/gen_app_icon.dart`는 파일명에 `_test`가 없어 `flutter test` 자동 스캔에서 제외됨. 명시 지정 시에만 실행.

### App Store Connect API key
- key_id / issuer_id / `.p8` 경로는 `ios/fastlane/Fastfile`의 `load_asc_api_key` 레인에 정의 (식별자 문서 평문 노출 금지).
- 개인키(`.p8`)는 리포 밖 `~/.appstoreconnect/private_keys/`에 보관.
- Bundle ID: `com.planroutine.app`
- 수동 폴백: `xcrun altool --upload-app --type ios --file build/ios/ipa/공직플랜.ipa --apiKey <key_id> --apiIssuer <issuer_id>` (값은 Fastfile 참조).

### 알려진 빌드 이슈
- 통합 테스트(simulator 빌드) 직후 바로 빌드하면 **simulator slice가 framework에 남아** altool 업로드 거부(91169). → **beta 레인**의 `reset_ios_caches`가 자동 차단(release는 빌드 없이 promote만 하므로 무관). 레인 밖 수동 빌드 시에는 `flutter clean && rm -rf ios/Pods ios/Podfile.lock ios/build && flutter build ipa`.

## 샘플 데이터
- `data/sample/2025_생산문서등록대장.csv` — **합성** 생산문서등록대장 20건 (가상 학교·가명, 실제 PII 없음)
  - 핵심 컬럼: 등록일자, 제목, 과제명, 과제카드명, 결재유형
  - 업무 분류·공개구분(공개/부분공개/비공개) 다양성을 갖춰 파서·필터 테스트용 커버리지 유지
  - ⚠️ 실제 학교 데이터 절대 커밋 금지 — 이 파일은 포맷 예시일 뿐(과거 실데이터는 히스토리에서 제거됨, 2026-07)

## 코딩 규칙
- Feature-first 구조: `lib/features/{기능}/data|domain|presentation/`
- Riverpod Provider: `presentation/providers/`에 배치
- Freezed 모델: 모든 도메인 모델에 `@freezed` 사용
- Null safety: `!` 강제 언래핑 금지
- 하드코딩 금지:
  - 문자열 → 공통은 `AppStrings`, 도메인은 각 `*Strings` 클래스
  - 색상 → `AppColors`, 크기 → `AppSizes`
- 파일명: snake_case / 클래스명: PascalCase
- 한글 UI, 한글 주석
- 삭제 시 반드시 `deleted_at IS NULL` 필터 동반
- **위젯 테스트에서 실제 DB I/O는 `tester.runAsync()` 안에서** — `testWidgets`의 fake-async
  존에서 sqflite FFI를 그냥 await하면 완료되지 않아 테스트가 10분 타임아웃까지 멈춘다.
  seed 삽입도 마찬가지. 화면이 뜰 때까지는 조건 폴링으로 기다린다
  (`schedule_screen_review_test.dart`·`today_screen_test.dart` 참고)
- 날짜 문자열 포맷은 `date_utils.formatDate(DateTime) → 'YYYY-MM-DD'` 공용 함수 사용
- 확인 다이얼로그는 `ConfirmDialog.show()` 공통 위젯 사용 (신규 AlertDialog 직접 만들지 않기)
- 설정 섹션 추가 시 `SettingsSection` wrapper + `widgets/{name}_list_tile.dart`에 위젯 분리
