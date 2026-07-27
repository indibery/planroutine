# PlanRoutine (공직플랜)

## 프로젝트 개요
**공직플랜** — 계획(Plan)과 반복(Routine). 초등 교사를 위한 업무 일정 관리 앱.
매년 반복되는 교사 업무 사이클을 작년 데이터 기반으로 올해 일정으로 빠르게 세팅.
**입력 탭**에서 넣고(월간 일정표 사진 → AI 변환 / 작년 CSV) 그 아래 검토 목록에서
확정하는 흐름이 핵심. 항목은 **업무**(내가 처리할 일)와 **행사**(학교에서 열리는 일)로 나뉜다.

## 핵심 기능
1. **입력 탭(주 경로: 사진 AI)** — 히어로에서 `① 프롬프트 복사 → AI 앱 다녀오기 → ② 붙여넣기` 왕복으로 행사를 등록. 앱은 네트워크를 쓰지 않고 클립보드만 오간다.
2. **작년 업무 가져오기(보조)** — 입력 탭 히어로 아래 테두리 카드 한 줄 → `/import` 풀스크린에서 CSV 업로드. **진입점은 이 한 곳뿐**(설정 탭에서 제거). 플랜루틴 자체 포맷 CSV는 재임포트 시 확정 상태로 즉시 복원.
3. **업무 / 행사 구분** — `EntryKind`(task/event). CSV 경로 = 업무, 사진 AI 경로 = 행사. 오늘 탭에는 업무만, 캘린더에는 둘 다.
4. **검토 후 확정** — 입력 탭 검토 목록에서 슬라이드로 확정(→) / 삭제(←). 하단 `일괄 업무 등록 N건` / `일괄 행사 등록 N건` pill로 종류별 일괄 확정(해당 종류 0건이면 숨김). 확정 시 캘린더 이벤트 자동 생성(종류 승계). 대기가 없으면 검토 영역은 요약 한 줄로 축소.
5. **자체 캘린더** — 앱 내 이벤트 CRUD, 양방향 스와이프 (→ Google 저장 / ← 완료 토글). 에듀파인 CSV로 가져왔고 아직 검토(편집 시트를 열어 저장)하지 않은 이벤트는 리스트에 테두리형 `작년` 출처 배지 노출(연도 자체는 보지 않는다 — 아래 "작년 배지" 참고) → 시트를 저장하면 배지가 꺼진다. 제목의 연도를 한 해씩 미는 칩은 편집 다이얼로그(수정 경로) 안에만 있고, 한 시트 안에서 한 번 누르면 다시 누를 수 없다.
6. **휴지통** — 일정/이벤트 soft-delete, 30일 후 자동 영구 삭제.
7. **내보내기** — 확정된 일정을 UTF-8 BOM CSV로 공유시트에 전달.
8. **Google 캘린더 연동** — 단방향(앱 → Google) 이벤트 저장, `google_event_id`로 중복 방지.
9. **로컬 알림** — 이번 주(월요일) · 당일 아침 08:00 알림 (timeSensitive).
10. **오늘 탭(첫 화면)** — 오늘 처리할 **업무**만 모아 체크 원 탭으로 완료. 완료 순간 골드
   도장이 찍히고 상단 결산 링이 차오른다. 기한이 지난 항목은 롤링 7일까지만 기본 접힘.

## 타깃 사용자
- 매년 비슷한 업무 사이클을 가진 초등 교사

## 기술 스택

| 레이어 | 기술 | 비고 |
|--------|------|------|
| 앱 | Flutter 3.x (Dart) | iOS 배포 중. Android는 코드는 있으나 미검증 |
| 상태 관리 | Riverpod | 다른 라이브러리 사용 금지 |
| 라우팅 | GoRouter | ShellRoute 4탭 (오늘/캘린더/입력/설정) + push(/trash, /import). 초기 라우트 `/today` |
| 로컬 DB | sqflite | 스키마 v8 (3 테이블, soft-delete + completed + google_event_id + kind + reviewed_at) |
| 모델 | Freezed + json_serializable | 불변 객체 |
| CSV 파싱 | csv + charset_converter | EUC-KR/UTF-8 BOM 자동 감지 |
| 파일 선택 | file_picker | |
| 공유 | share_plus, path_provider | 임시 디렉토리 + 공유시트 |
| 앱 정보 | package_info_plus | 설정 탭 버전 표시 |
| 영구 설정 | shared_preferences | 알림 설정, 힌트 바 dismiss, 화면 테마, 완료 도장 |
| 구글 | google_sign_in 6.x + googleapis 13.x + http | 단방향 Calendar API |
| 알림 | flutter_local_notifications + timezone | 로컬 TZ 예약, timeSensitive |
| 날짜 | intl | 한국어 로케일 |
| 테스트 | flutter_test, integration_test, sqflite_common_ffi | 480 유닛/위젯 + 19 E2E |

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
│   │   ├── database/                   # DatabaseHelper (v8, forTesting 생성자)
│   │   └── utils/                      # date_utils (formatDate)
│   ├── features/
│   │   ├── import/                     # 넣기 (사진 AI + 작년 CSV)
│   │   │   ├── data/                   # csv_parser, import_repository, ai_schedule_parser/register
│   │   │   ├── domain/                 # imported_schedule
│   │   │   └── presentation/
│   │   │       ├── ai_photo_flow.dart          # 프롬프트 복사 / 붙여넣기+미리보기 (히어로·가져오기 화면 공유)
│   │   │       ├── screens/import_screen.dart  # 작년 업무 CSV 전용 풀스크린 + sticky 스테퍼
│   │   │       ├── widgets/
│   │   │       │   ├── photo_input_hero.dart   # 입력 탭 히어로 (왕복 3단 + CSV 보조 카드)
│   │   │       │   ├── import_summary_card.dart
│   │   │       │   └── edufine_guide_section.dart  # 2단 접힘 안내 + 팁 박스
│   │   │       └── providers/                   # importStateProvider (importFromPath API)
│   │   ├── schedule/                   # 입력 탭 (넣기 + 검토/확정)
│   │   │   ├── data/                   # schedule_repository (soft-delete + purge, kind 필터)
│   │   │   ├── domain/                 # schedule, entry_kind(task/event), filter_summary(순수 함수)
│   │   │   └── presentation/           # ScheduleScreen, SlideHintBar, EditSheet, FilterBar(상태/종류/카테고리)
│   │   ├── calendar/                   # 자체 캘린더
│   │   │   ├── data/                   # calendar_repository
│   │   │   ├── domain/                 # calendar_event (deletedAt/completedAt/kind)
│   │   │   └── presentation/           # CalendarScreen, EventEditDialog, ListSection
│   │   ├── trash/                      # 휴지통
│   │   │   └── presentation/           # TrashScreen + snapshot
│   │   ├── settings/                   # 설정 탭 (섹션별 위젯 분리)
│   │   │   ├── data/                   # app_reset_repository, schedule_csv_exporter
│   │   │   └── presentation/
│   │   │       ├── screens/settings_screen.dart   # 얇은 조합
│   │   │       ├── widgets/
│   │   │       │   ├── settings_section.dart       # 헤더+본문+Divider wrapper
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
│   ├── features/                       # 단위/위젯 테스트
│   │   ├── calendar/data/
│   │   ├── schedule/data/
│   │   ├── notifications/              # computeNotifications
│   │   ├── import/                     # parser + domain
│   │   └── schedule/domain/
│   ├── helpers/test_database.dart      # FFI in-memory DB 팩토리
│   └── tools/gen_app_icon.dart         # 1024×1024 PNG 렌더 (자동 스캔 제외)
└── integration_test/
    └── app_test.dart                   # UX E2E 20 시나리오
```

## 데이터베이스 스키마 (v8)

### schedules
- `id`, `title`, `description`, `scheduled_date`
- `category`, `sub_category`, `source_id` → imported_schedules
- `status` (pending/confirmed)
- **`kind`** (v7): `task`(업무) / `event`(행사), DEFAULT `'task'`
- `created_at`, `updated_at`, **`deleted_at`** (NULL=활성)

### calendar_events
- `id`, `title`, `description`, `event_date`, `end_date`, `is_all_day`, `color`
- `schedule_id` → schedules
- `created_at`, `updated_at`
- **`deleted_at`** (v2): NULL=활성, ISO=휴지통
- **`completed_at`** (v3): NULL=미완료, ISO=완료 시각
- **`google_event_id`** (v4): NULL=미저장, 값 있으면 재저장 시 update (중복 방지)
- **`device_event_id`** (v5): 기기 캘린더 저장 식별자
- **`is_important`** (v6): 0/1 — 미완료일 때만 골드 강조(`showsImportant`)
- **`kind`** (v7): `task`/`event`. 확정 시 `schedules.kind`를 승계한다
- **`reviewed_at`** (v8): NULL=아직 검토 안 함, ISO=편집 시트 저장 시각. 연도를 고쳤는지는
  구분하지 않는다 — 저장 자체가 검토의 증거(아래 "작년 배지" 참고)

### imported_schedules
- 원본 생산문서등록대장 CSV 보관. PlanRoutine export 포맷 임포트는 이 테이블을 건너뛰고 schedules로 직접 삽입.

### 마이그레이션
- `DatabaseHelper._onUpgrade`: v1→v2(deleted_at), v2→v3(completed_at), v3→v4(google_event_id),
  v4→v5(device_event_id), v5→v6(is_important), v6→v7(kind, 두 테이블), v7→v8(reviewed_at).
  기존 사용자도 ALTER TABLE로 데이터 유지한 채 업그레이드.
- v7의 `DEFAULT 'task'`가 곧 제품 결정이다 — **기존 데이터는 전부 업무**(지금까지 들어온 것은
  사실상 전부 CSV). 별도 백필 스크립트가 없는 이유.

## 주요 설계 결정

### Soft-delete
- 삭제는 `UPDATE deleted_at = NOW()`. 활성 쿼리는 `WHERE deleted_at IS NULL` 필수.
- `getDeletedX` / `restoreX` / `permanentDeleteX` / `purgeOlderThan` API.
- 앱 시작 시 30일 초과 항목 자동 영구 삭제 (main.dart).

### 중복 체크
- `createFromImported` / `insertConfirmedOrPending` / `createFromSchedule` 모두 `deleted_at IS NULL` 기준.
  즉 휴지통에 같은 항목 있어도 재생성 허용.

### 편집 시트는 반드시 `copyWith` (필드 유실 방지)
- `EventEditDialog._buildEvent()`의 **편집 분기는 `existing.copyWith(...)`** 여야 한다. 생성자로
  `CalendarEvent`를 새로 만들면 시트가 모르는 필드가 `@Default`/null로 되돌아가고,
  `updateEvent`의 `toMap()`이 그 값으로 DB를 덮는다.
- 실제로 그렇게 잃었던 것: `kind`(행사 → 업무, 오늘 탭에 운동회가 뜬다) ·
  `googleEventId`(연결이 끊겨 재저장 시 Google에 **중복 이벤트**) · `deviceEventId`.
  `completedAt`은 `toMap()`에 없어 우연히 무사했을 뿐이다.
- **원인은 필드 하나가 아니라 패턴이다** — 생성자 조립을 되살리면 다음 필드에서 재발한다.
  `test/features/calendar/event_edit_dialog_preserve_test.dart`의 보존 가드가 이 회귀를 막는다.
- 예외는 `endDate` 하나뿐이다: 시작일을 옛 종료일보다 뒤로 옮기면 `endDate: null`로 **정리**한다.
  종료일 입력이 UI에서 사라져 사용자가 모순을 고칠 방법이 없기 때문(아래 참조).

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

### 일정 추가/수정 시트
- 구성: 제목 · (연도 칩, **수정 시에만**) · 설명(`minLines 4 / maxLines 6`) · 날짜 · **성격 카드** · 취소/저장.
- **성격 카드** = 종류 세그먼트(`SegmentedSettingRow<EntryKind>`) + `Divider` + 중요 스위치를
  한 테두리에. 종류 행을 숨길 때는 **`Divider`도 함께** 뺀다 — 구분선만 남으면 잘린 것처럼 읽힌다.
- **종료 날짜 입력은 없다.** `getEventsByDateRange`가 `event_date`만 보므로 기간은 앱 안에서
  아무 일도 하지 않았다(3일짜리도 시작일 하루에만 점이 찍힌다). 실효는 Google/기기 캘린더로
  기간 이벤트를 내보낼 때뿐이라 **DB 컬럼·모델·내보내기 경로는 그대로 두고 입력만** 없앴다.
  회수한 48+8px은 설명칸이 가져갔다.
- 중요 표시는 **두 종류 모두에서** 유지한다 — 캘린더 ★ 강조는 학교 행사에도 의미가 있다.

### 목록의 중요 표시는 세로를 쓰지 않는다
- 중요 이벤트는 골드 신호가 네 겹이었다: 레일 · 카드 배경 14% · 테두리 50% · `★ 중요` 배지.
  앞의 셋은 세로를 안 쓰는데 배지만 약 25px을 써 중요 행이 35%쯤 높았다.
- 배지 줄을 없애고 **★ 아이콘만 종류 배지 뒤·제목 앞 인라인**으로 둔다. 중요 행과 보통 행의
  높이가 같아진다. 글자가 사라지므로 `Semantics(label: CalendarStrings.importantBadge)`로 감싼다
  (상수는 스크린리더 라벨로 계속 쓰이니 지우지 말 것).
- **★ 자체는 지우지 않는다** — 남은 신호 셋이 전부 색이라 형태(★)가 마지막 비색상 단서다.
- `_goldPill`·연도 배지(`_buildYearBadge`)는 이번에 **둘 다 없어졌다** — 목록에는 대신
  출처 표시인 `작년` 배지(`_buildImportBadge`)가 붙는다(위 "제목 연도 바꾸기" 참고).
  E2E에서 ★를 찾을 때는 격자 셀도 같은 `Icons.star_rounded`를 쓰므로
  `find.descendant(of: find.byType(EventListSection), ...)`로 한정한다.

### 업무 / 행사 (EntryKind)
- `lib/features/schedule/domain/entry_kind.dart` — `task`(업무) / `event`(행사). DB 값은 `'task'`/`'event'`, 모르는 값·null은 업무로 폴백.
- **표시 이름은 `label` 하나**다(`ScheduleStrings.kindTask`/`kindEvent` 참조). 예전에는 짧은
  `label`(`일정`)과 긴 `filterLabel`(`학교일정`)로 나뉘어 있었는데, 짧은 쪽이 우산말 `일정`과
  겹쳐 업무와의 대비가 약했다. `행사`는 2글자로도 충분히 강해 그 분리가 필요 없어져 합쳤다.
- **입력 경로가 종류를 결정한다**: 작년 CSV(생산문서등록대장) → 업무 / 월간 일정표 사진 AI → 행사. 두 경로 모두 `status=pending`으로 들어와 같은 검토 관문을 지난다.
- **승계 지점이 급소**: `CalendarRepository.createFromSchedule`이 `schedules.kind`를 이벤트로 옮긴다. 여기서 끊기면 데이터는 멀쩡한데 오늘 탭에 운동회가 뜨는, 원인이 두 레이어 떨어진 버그가 된다.
- `buildTodayView`가 `e.kind.showsInToday`로 걸러 **오늘 탭은 업무만** 담는다 — 행사에는 완료 개념이 없어 도장·진행 링의 의미가 깨진다.
- 캘린더는 둘 다 보여준다. 월 그리드 점의 종류별 색 구분은 하지 않는다(색 규칙이 이미 골드=오늘·중요, 붉은색=공휴일·일요일, 파랑=토요일·이벤트로 포화). **대신 목록 행에서 구분한다** — 제목 앞 인라인 `KindBadge`(업무=회색 `sub` / 행사=파랑 `info`, 옅은배경 15% + 10px w700).
- `KindBadge`는 `features/schedule/presentation/widgets/`에 산다(`shared/widgets/`가 아니다). `EntryKind`에 종속인데 `shared/widgets/` 아래 어떤 위젯도 `features/`를 import 하지 않기 때문 — 캘린더가 schedule을 가져다 쓰는 방향은 이미 `calendar_event.dart`에 있다.
- **시트에서 종류를 고를 수 있다**(캘린더 경로만). 손으로 넣은 항목이 전부 업무가 되던 문제를 없앤다. **오늘 탭에서 열면 종류 행을 숨긴다**(`allowKindChange: false`) — 거기서 행사를 만들면 저장 직후 목록에서 사라져 저장 실패로 읽힌다. 행만 숨기고 `_kind` 상태는 살려둬야 오늘 탭에서 편집해도 종류가 보존된다.
- 캘린더에서 종류를 바꿔도 원본 `schedules.kind`는 그대로다(역방향 동기화 없음). `scheduleId`가 있는 이벤트의 종류를 뒤집으면 입력 탭 확정 목록과 캘린더의 배지가 어긋나고 CSV 내보내기는 옛 종류로 나간다. 빈도가 낮아 두고 있는 상태이지 버그가 아니다.

### 입력 탭 구조
- **넣기가 주인공**, 검토는 그 아래. 화면 제목 `입력`(eyebrow `INPUT`), 탭 라벨 `입력`.
- `PhotoInputHero`(import feature) — 왕복 3단 `① 프롬프트 · AI 앱 · ② 붙여넣기`. 가운데 칸은 앱 밖에서 벌어지는 일이라 **누를 수 없다**. 작년 업무 CSV는 아래 **테두리 카드 한 줄**(옅은 글씨면 학기 초에 못 찾는다 — 히어로는 골드 채움이라 위계는 유지된다).
- AI 동작 자체는 `import/presentation/ai_photo_flow.dart`의 `copyAiPhotoPrompt`/`pasteAiSchedulesAndPreview`에 있다 — 히어로와 가져오기 화면 섹션이 같은 로직을 공유한다.
- 하단 종류별 일괄 등록 바 — `일괄 업무 등록 N건` / `일괄 행사 등록 N건`. 건수는 **현재 뷰**(카테고리·종류 필터 반영) 기준이고 0이면 그 pill은 숨는다.
  - 라벨은 `ScheduleStrings.bulkRegister(kind.label, n)`으로 **조립**한다 — `업무`/`행사`를 여기 다시 박으면 다음 용어 변경 때 배지·칩만 따라가고 pill만 옛 이름으로 남는다(직전 main이 그 상태였다: `kindEvent`는 `학교일정`, pill은 `일괄 일정 등록`).
  - "0건이면 숨는다" 가드는 **`ScheduleScreen.bulkRegister{Task,Event}Key`** 로 검사한다. 문자열 `findsNothing`은 라벨을 한 번만 손봐도 아무 데서도 렌더되지 않는 문자열을 찾게 돼 0건 pill을 보고도 통과한다.
- **필터는 접힌다** — 접힘: `[검토 대기 21 · 업무] [21건 삭제] [⌄]` 한 줄(약 41px) / 펼침: 라벨 `필터` + 칩 3줄(상태 · 종류 · 카테고리). 히어로가 위쪽 210px을 쓰므로 칩을 항상 펼쳐두면 iPhone에서 목록이 두어 칸만 남는다. 그렇다고 필터를 바텀시트로 보내면 지금 무엇으로 걸러졌는지 알 수 없어, **요약은 남기고 칩만 접는다**.
  - **기본은 접힘**(대기가 있어도). 이 탭의 목적은 넣기와 검토 목록에 높이를 내주는 것이고, 필터를 쓰는 순간은 그보다 드물다. 접힌 줄이 현재 필터를 말해주므로 정보 손실이 없다. 사용자가 탭하면 그 선택이 화면 수명 동안 우선한다(저장하지 않는다).
  - **펼친 상태에서는 요약 문구를 감춘다** — 안 감추면 요약 `검토 대기 21`과 상태 칩 `검토 대기 21`이 같은 말을 반복한다(진행도 텍스트를 없앤 이유와 같은 함정).
  - 접힘일 때만 요약을 테두리 pill로 감싼다. 그때는 이 줄이 유일한 필터 조작부라 눌러 보여야 하고, 펼치면 칩이 주역이라 조용해져야 한다.
  - 종류 칩은 **토글**이고 '전체' 칩이 없다 — 카테고리 줄의 '전체'와 헷갈린다. 탭 대상은 `ScheduleFilterBar.kind{Task,Event}Key`로 찾는다(라벨은 대기 뷰에서만 건수가 붙고 `행사` ⊂ `학교행사`라 문자열로 찾으면 카테고리 칩·건수 포맷에 묶인다).
  - **접힌 요약의 건수는 `schedulesProvider`의 현재 목록 길이**다(`buildFilterSummary(visibleCount:)`). 전역 건수를 쓰면 좁혀서 빈 화면인데 `검토 대기 21`이라고 우긴다. 펼친 상태의 상태 칩은 전역 건수 그대로 — 둘은 동시에 보이지 않는다.
  - **종류 칩의 건수는 카테고리 필터를 반영**하고(`scheduleCountsProvider`) 종류 필터는 반영하지 않는다. 반영 안 하면 `행사 4`를 눌렀는데 빈 화면이 나오고, 종류까지 반영하면 지금 안 보는 종류가 몇 건인지 몰라 넘어갈 수 없다.
- **진행도는 2px 바만** 남긴다. `149 / 149 · 100% 완료` 텍스트는 필터 요약의 `확정됨 149`와 같은 말이라 43px을 중복에 쓰고 있었다. 바는 필터 요약 줄 **바로 위**에 붙이고 좌우 여백을 필터 줄과 맞춘다 — 떼어놓으면 정보가 아니라 장식으로 읽힌다.
- 일괄 삭제 pill은 진행도 행이 사라졌으므로 **필터 요약 줄의 `trailing`** 으로 들어간다.
  - **삭제 범위는 확정과 대칭이어야 한다** — `deleteAllPending`도 `confirmAllPending`처럼 카테고리·종류를 **둘 다** 받는다. 건수는 좁힌 뷰에서 나오는데 삭제만 종류를 무시하던 시절엔 `행사 4건 삭제`를 눌러 대기 21건이 전부 휴지통으로 갔고, 스낵바는 `4건을 옮겼어요`라 사라진 사실조차 알리지 않았다. 다이얼로그 범위 이름도 같은 두 값에서 만든다(`buildScopeLabel`) — 문구와 쿼리가 어긋나면 되돌리기 어려운 삭제가 조용히 커진다.
  - 그 대칭은 **코드로** 강제한다: 두 메서드는 `ScheduleRepository._updateAllPending(values, {category, kind})` 하나를 감싼 3줄 wrapper이고, WHERE 조립은 그 안에만 있다. 한쪽에만 필터를 추가해 어긋난 것이 바로 위 버그였으므로 doc 주석으로 지키지 않는다 — 다음 필터(subCategory·기간)도 한 곳만 고치면 양쪽에 걸린다.
- 대기 0 + 대기 뷰이면 필터 바 자체를 숨기고, 검토 영역은 `검토 대기 없음 · 확정 N건` + 보기 링크 한 줄로 축소된다(필터 요약과 중복되지 않게). 넣기 CTA를 여기 또 세우지 않는다(히어로가 바로 위에 있다).

### 용어
- **일정 / 행사 / 업무**를 쓴다. `학교일정`은 쓰지 않는다 — `일정`이 우산말(시트 제목
  `일정 추가/수정`)이자 라벨의 절반이라 겹쳐 읽혔다(사용자 신고, 2026-07-27).
- **`행사`가 에듀파인 카테고리 `학교행사`와 부딪히는 범위**: 배타적인 것은 **한 행 안**
  뿐이다. 카테고리 배지는 `schedule.category != null`일 때만 렌더되고
  (`schedule_tile.dart`), `category`를 채우는 경로는 CSV 경로
  (`createFromImported`·`createBulkFromImported`·`_importPlanRoutineCsv`)뿐이며 그 경로는
  항상 업무다. 사진 AI 경로(= 행사)는 `registerAiSchedules`가 `category`를 넣지 않는다.
  캘린더 목록에는 카테고리 배지 자체가 없다. **한 항목이 두 낱말을 동시에 다는 일은 없다.**
  (이전에는 이 혼동을 걱정해 "행사" 사용을 금지했었다 — 근거를 확인하고 뒤집었다.)
  - ⚠️ **화면 단위로는 세 곳에서 공존한다.** 한 행 안의 배타성이 화면 전체의 배타성을
    뜻하지는 않는다 — 아래 셋은 알고 감당하는 지점이지 안전이 증명된 곳이 아니다.
    1. **검토 목록의 인접 행.** CSV와 사진 AI가 모두 `status=pending`으로 같은 목록에
       들어오고 종류 필터 기본값은 null(전체)이라 `[업무] … [학교행사]` 행과 `[행사] 입학식`
       행이 나란히 뜬다. 변경 전 배지가 `일정`일 때는 없던 반향이다(`행사` ⊂ `학교행사`).
    2. **펼친 필터 패널.** `_KindRow`의 `[업무][행사]` 바로 아래 `_CategoryRow`가
       `shortenCategory()`의 `학교행사` 칩을 그린다. 펼친 헤더는 `필터` 한 단어뿐이라
       행별 라벨도 없다.
    3. **접힌 필터 요약 한 줄.** 두 필터를 함께 켜면 `검토 대기 0 · 행사 · 학교행사`가 된다.
  - 감당 가능한 이유: 선택의 의미가 다르고(하나는 종류, 하나는 카테고리) 카테고리 칩·배지는
    CSV 경로(=업무) 항목에만 붙는다. 바꿔야 할 만큼 커지면 손댈 곳은 `_CategoryRow`가 아니라
    `category_label.dart`의 축약 규칙이다(에듀파인 원본 분류명은 그대로 두는 것이 원칙).
- 예외 둘:
  - `category_label.dart`의 `학교행사` — 에듀파인 실제 분류명이라 그대로 둔다.
  - **AI 프롬프트 본문**(`ai_schedule_parser.dart`의 `buildAiPhotoPrompt`) — `학교 월간·연간
    일정표`처럼 **소스 문서를 설명하는 말**이라 UI 용어와 청중이 다르다. 우리 분류에 맞춰
    고치면 추출 품질이 흔들릴 수 있어 건드리지 않는다.

### 스와이프 UX
| 탭 | 오른쪽(→) | 왼쪽(←) |
|---|---|---|
| 입력(검토 목록) | 확정 | 삭제(soft) |
| 캘린더 | Google 저장 | 완료 토글 |
- 각 탭 상단에 2줄 안내 바 (SharedPreferences로 영구 닫기 가능).

### 제목 연도 바꾸기
- 임포트는 날짜(scheduled_date)만 올해로 변환하고 **제목 문자열의 연도는 원본 유지**(의도적). 그래서 "2025학년도 …" 제목이 남는다.
- `core/utils/title_year_utils.dart`의 순수 함수 `shiftTitleYears(title, {int by = 1})`가 치환 담당(`currentYear` 인자 없음). 정규식 `(?<!\d)20\d\d(?!\d)`로 4자리 연도만 매칭(문서번호·"1000명" 등 비연도 차단)하고, **크기에 따른 예외 없이 제목 안의 모든 연도를 한 해씩 민다**. 반환 `from`은 **중복 제거된 등장 순서** 원본 연도 목록 — 호출부가 이 길이로 라벨을 고른다(1개면 `2025 → 2026`, 2개 이상이면 `연도 모두 +N년`).
  - **왜 상대 기준(한 해 밀기)인가**: "올해로 맞추기"(예전 `bumpTitleYear`, 올해보다 작은 연도만 치환)는 한 제목 안의 서로 다른 연도를 뭉갠다 — `2025학년도 안건[2026학년도 개정]`이 올해(2026)로 맞추면 둘 다 2026이 돼 "올해 발의한 내년 규정"이라는 관계가 사라진다. 한 해씩 밀면 `2026학년도 안건[2027학년도 개정]`으로 간격이 그대로 보존된다. 12월 업무 제목의 "2026 졸업식"이 두 달 뒤(2월) 졸업식을 가리키는 것처럼, 연도들의 상대적 관계가 뜻을 만든다.
- **노출 지점은 편집 칩 1곳**(`EventEditDialog` 제목 아래 실시간 칩, 입력 중 연도 감지 시 노출) — 목록의 골드 연도 배지는 없앴다(아래 "작년 배지" 참고).
  - 이 칩은 **수정 경로에서만** 뜬다(`_isEditing`). `EventEditDialog.show`는 생성에도 쓰이는데(캘린더·오늘 탭 FAB), 신규 생성 중에는 방금 본인이 타이핑한 연도라 밀라고 권할 이유가 없다(사용자 확인, 2026-07-26).
  - **칩이 꺼지는 이유는 셋, 수명은 제각각이다**: `!_isEditing`(신규 생성 — 편집 경로가 아님, 영구) /
    `reviewedAt != null`(이미 검토해 저장한 항목, 영구·DB) / `_yearShifted`(이 시트를 여는 동안
    이미 한 번 눌렀음, **세션 한정** — 취소하면 사라져 다시 열면 칩이 돌아온다).
  - **"저장이 유일한 기준"의 구조적 근거**: `toMap()`을 쓰는 경로는 `createEvent`(insert)와
    `updateEvent`(update) 둘이고, **기존 행의 `reviewed_at`을 변경**할 수 있는 것은 `updateEvent`
    하나다. 나머지(`markCompleted`·`markIncomplete`·`_updateExternalEventId`·`deleteEvent`·
    `restoreEvent`)는 각자 컬럼만 담은 리터럴 맵을 쓴다 — Google/기기 저장 스와이프나 완료
    토글만으로는 `reviewed_at`이 구조적으로 바뀌지 않는다.
- **작년 배지**(목록, 골드 연도 배지의 대체): 판정 기준은 `schedules.source_id != null && calendar_events.reviewed_at IS NULL`(DB v8) — **에듀파인 CSV 경로 한정**(`createFromImported`·`createBulkFromImported`만 `source_id`를 채움)**이면서 아직 검토(편집 시트 저장)하지 않은 것만**. 사진 AI, 손입력, 그리고 플랜루틴 export CSV 재임포트(`_importPlanRoutineCsv`, `sourceId` 없음)는 배지를 받지 않는다. 배지는 **테두리형**(종류 배지는 채움) — 둘 다 `AppColors.sub`라 형태로만 구분된다.
  - **배지의 뜻은 "아직 검토 안 한 항목"이지 "아직 옛 연도인 항목"이 아니다.** `reviewed_at`은
    연도를 고쳤는지와 무관하게 편집 시트의 **모든 저장**에서 기록된다(중요 스위치만 바꿔도,
    날짜만 옮겨도 기록된다) — 그래야 연도 없는 제목(`종업식 및 졸업식 학사일정변경 안내장`)도
    배지를 지울 방법이 생긴다. 그 대가로 연도 색인(직전 작업이 남긴 "아직 제목이 옛 연도인
    항목을 찾을 수 없다"는 부채)은 **근사치로만 갚였다** — "아직 안 열어본 것"과 "아직 옛
    연도인 것"은 다른 집합이고, 후자를 보려면 개별 항목을 열어 편집 칩을 확인하는 수밖에 없다.
  - `CalendarEvent.fromImport`는 `getEventsByDateRange`의 LEFT JOIN으로 채우는 **조회 시점 파생 필드**이고 **`toMap()`에 넣지 않는다** — 넣으면 `from_import` 컬럼이 없는 테이블에 insert가 깨진다. 가드 테스트가 `calendar_repository_test.dart`에 있다.
  - 목록 규칙을 연도에서 파생시키면(`<`를 `<=`로) 고칠 때마다 다시 조르는 순환이 된다 — 그래서 **조르는 쪽(목록)과 고치는 쪽(편집 칩)의 기준을 분리**했다. 목록은 출처만 보고 연도를 아예 안 본다.
  - ⚠️ **조인의 대가**: 확정된 일정을 입력 탭에서 삭제하고 30일이 지나면 `purgeOlderThan`이 `schedules` 행을 hard-delete 하는데, `PRAGMA foreign_keys`가 꺼져 있어 `calendar_events.schedule_id`는 dangling으로 남는다 → 조인 미스 → **배지가 조용히 사라진다**. 컬럼이었다면 살아남았을 유일한 케이스다. (soft-delete만으로는 안 사라진다 — 조인에 `s.deleted_at` 필터가 없어 휴지통에 든 스케줄도 배지를 유지하며, 이건 의도된 동작이다.)

### CSV 라운드트립
- **내보내기**: `schedules`의 확정(`status=confirmed`)만. 컬럼: 제목/등록일자/카테고리/설명/상태. UTF-8 BOM.
- **가져오기 감지**: 헤더에 "상태" 컬럼 있으면 PlanRoutine export로 인식 → imported_schedules 건너뛰고 schedules에 직접 insert + 캘린더 이벤트 자동 생성.
- 원본 생산문서등록대장 CSV는 기존 흐름 유지(imported_schedules → 전체 등록 버튼 → pending).

### 설정 탭 구조
- `settings_screen.dart`는 100줄 미만의 얇은 조합. 각 섹션 UI는 `widgets/*_list_tile.dart`에 분리.
- `SettingsSection` wrapper가 헤더(title+subtitle) + 본문 + Divider 3종 세트를 1줄로 묶는다.
- 확인 다이얼로그는 `shared/widgets/confirm_dialog.dart`의 `ConfirmDialog.show()` 공통 사용.

### Import 플로우 (`/import` = 작년 업무 CSV 전용)
- **이 화면에 사진 AI를 두지 않는다.** '작년 업무 가져오기'를 눌러 들어온 사람에게 "행사를 사진으로"가 크게 뜨면 엉뚱한 화면이 된다(실기기 피드백). 사진 AI는 입력 탭 히어로가 맡는다.
- 화면 제목은 `ImportStrings.screenTitle`(`작년 업무 가져오기`). 진입점은 입력 탭 히어로의 CSV 카드 하나뿐 — **설정 탭의 가져오기 섹션은 제거**(히어로와 중복).
- 탭 시 `/import`로 push (ShellRoute 내부라 탭바 유지).
- **등록이 끝나면 자동으로 입력 탭으로 돌아간다.** `ImportScreen`이 `importStateProvider`를 listen해 `ImportRegistered`가 되면 `reset()` → `pop()`(공유시트로 곧바로 열려 pop할 스택이 없으면 `go(/schedule)`) → 스낵바로 건수 안내. 등록 완료 화면에는 할 일이 없다 — 대기 건수는 입력 탭의 `검토 대기 N`이 이미 말해주고, 다음 행동은 그 목록에서 확정하는 것이다. 그래서 `ImportRegistered` 뷰는 그리지 않는다(`SizedBox.shrink`).
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
- `shared/widgets/floating_tab_bar.dart`(이름은 과거 플로팅 디자인의 잔재) — 실제로는 화면 폭을 꽉 채운 불투명 바(배경 = 테마 surface색: 다크 navyMid / 라이트 흰색) + 상단 1px 골드 라인. 4탭 = **오늘 / 캘린더 / 입력 / 설정**. `extendBody: false`라 리스트가 탭바 뒤로 비치지 않고 FAB도 Scaffold가 자동으로 바 위에 올려준다.
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
