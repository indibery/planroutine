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
5. **자체 캘린더** — 앱 내 이벤트 CRUD, 양방향 스와이프 (→ 외부 캘린더 저장 / ← 완료 토글). 에듀파인 CSV로 가져왔고 아직 검토(편집 시트를 열어 저장)하지 않은 이벤트는 리스트에 테두리형 `작년` 출처 배지 노출(연도 자체는 보지 않는다 — 아래 "작년 배지" 참고) → 시트를 저장하면 배지가 꺼진다. 제목의 연도를 한 해씩 미는 칩은 편집 다이얼로그(수정 경로) 안에만 있고, 한 시트 안에서 한 번 누르면 다시 누를 수 없다.
6. **휴지통** — 일정/이벤트 soft-delete, 30일 후 자동 영구 삭제.
7. **내보내기** — 확정된 일정을 UTF-8 BOM CSV로 공유시트에 전달.
8. **Google 캘린더 연동(iOS 전용)** — 단방향(앱 → Google) 이벤트 저장, `google_event_id`로 중복 방지. **안드로이드에서는 선택지를 감춘다** — 거기서는 기기 캘린더가 이미 구글 캘린더다(아래 설계 결정 참고).
9. **로컬 알림** — 이번 주(월요일) · 당일 아침 08:00 알림 (timeSensitive).
10. **오늘 탭(첫 화면)** — 오늘 처리할 **업무**만 모아 체크 원 탭으로 완료. 완료 순간 골드
   도장이 찍히고 상단 결산 링이 차오른다. 기한이 지난 항목은 롤링 7일까지만 기본 접힘.
11. **출퇴근 버스 도착 카드** — 오늘 탭 맨 위. **기본 꺼짐**(설정 › 버스 도착). 출발지·도착지
   정류장을 하나씩 등록해 두면 시간대에 따라 알아서 바꿔 보여준다. 조회 간격은 **도착
   시점을 겨냥해 적응**하고(`min(300초, 1차+30초)`), 접거나 백그라운드면 중단, 막차 뒤에도
   중단. 화면은 1초마다 다시 그려 점이 흐른다. 공공데이터를 기기에서 직접 부르고
   **자체 서버가 없다**.

## 타깃 사용자
- 매년 비슷한 업무 사이클을 가진 초등 교사

## 기술 스택

| 레이어 | 기술 | 비고 |
|--------|------|------|
| 앱 | Flutter **3.44.8** (Dart 3.12.2) | iOS 배포 중(App Store). Android는 Play 비공개 테스트 진행 중 — **알림은 M2-①로 배선 완료**(2026-08-08, 에뮬레이터 실측). CSV 공유 목록 노출은 아직 M2. ⚠️ **리포에 버전 고정 장치가 없다**(fvm·CI 없음) — 이 칸이 유일한 기록이다(2026-08-03 3.41.6에서 올림) |
| 상태 관리 | Riverpod | 다른 라이브러리 사용 금지 |
| 라우팅 | GoRouter | ShellRoute 4탭 (오늘/캘린더/입력/설정) + push(/trash, /import, /bus/settings, /bus/stops). 초기 라우트 `/today` |
| 로컬 DB | sqflite | 스키마 v8 (3 테이블, soft-delete + completed + google_event_id + kind + reviewed_at) |
| 모델 | Freezed + json_serializable | 불변 객체 |
| CSV 파싱 | csv + charset_converter | EUC-KR/UTF-8 BOM 자동 감지 |
| 파일 선택 | file_picker | |
| 공유 | share_plus, path_provider | 임시 디렉토리 + 공유시트 |
| 앱 정보 | package_info_plus | 설정 탭 버전 표시 |
| 영구 설정 | shared_preferences | 알림 설정, 힌트 바 dismiss, 화면 테마, 완료 도장, 버스 설정 |
| 구글 | google_sign_in 6.x + googleapis 13.x + http | 단방향 Calendar API. **iOS 전용** — 안드로이드는 선택지를 감춘다 |
| 알림 | flutter_local_notifications + timezone | 로컬 TZ 예약, timeSensitive |
| 공공데이터 | http (직접 호출) | 버스 도착·정류소. **자체 서버 없음**. 키는 `--dart-define-from-file` |
| 날짜 | intl | 한국어 로케일 |
| 테스트 | flutter_test, integration_test, sqflite_common_ffi | **1003** 유닛/위젯 + 19 E2E (실측 2026-08-13. 926으로 적혀 있던 값이 오래 낡아 있었다 — 이 숫자를 지키는 가드는 없다) |

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
│   │   │       ├── screens/
│   │   │       │   ├── settings_screen.dart        # 얇은 조합
│   │   │       │   └── bus_settings_screen.dart    # /bus/settings — BusSettingsTiles를 감싼다
│   │   │       ├── widgets/
│   │   │       │   ├── settings_section.dart       # 헤더+본문+Divider wrapper
│   │   │       │   ├── export_list_tile.dart
│   │   │       │   ├── google_account_list_tile.dart
│   │   │       │   ├── notification_settings_tiles.dart
│   │   │       │   ├── stamp_settings_tiles.dart   # 도장 모양 한 줄 + 흐리게
│   │   │       │   ├── stamp_style_sheet.dart      # 도장 모양 2열 그리드 시트
│   │   │       │   ├── bus_settings_tiles.dart     # 버스 설정 본문 (화면이 감싼다)
│   │   │       │   ├── bus_summary_list_tile.dart  # 설정 탭 버스 요약 한 줄
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
│   │   │           ├── completion_seal.dart     # 완료 도장 (4종, SealMark 분기)
│   │   │           ├── seal_panda_mark.dart    # 판다 (CustomPainter)
│   │   │           └── seal_gecko_mark.dart    # 도마뱀 (PNG 알파 마스크 + srcIn)
│   │   ├── bus/                        # 출퇴근 버스 도착 카드
│   │   │   ├── data/
│   │   │   │   ├── bus_api_client.dart          # 소스 라우팅(지역별) + 30초 메모리 캐시
│   │   │   │   ├── tago_response_parser.dart    # 국토교통부 TAGO
│   │   │   │   └── gbis_response_parser.dart    # 경기도 GBIS + 지역별 nodeId 접두
│   │   │   ├── domain/
│   │   │   │   ├── bus_card_view.dart           # buildBusCardView(순수 함수) + 5상태
│   │   │   │   ├── bus_route.dart               # 경유노선 + buildRouteChoices(순수 함수)
│   │   │   │   ├── bus_arrival.dart · bus_stop.dart · bus_settings.dart
│   │   │   │   ├── commute_direction.dart · time_range.dart · bus_card_style.dart
│   │   │   │   └── bus_display.dart
│   │   │   └── presentation/
│   │   │       ├── screens/bus_stop_search_screen.dart  # 이름 검색(주) + 지역 모드(보조)
│   │   │       └── widgets/
│   │   │           ├── bus_card_host.dart              # 폴링·수명·시간대 판정
│   │   │           ├── bus_arrival_card.dart           # 제목줄 + 접힘 토글
│   │   │           ├── bus_body_text.dart · bus_body_axis.dart  # 모양 2종
│   │   │           ├── bus_stop_confirm_sheet.dart     # 등록 직전 방향 확인
│   │   │           └── bus_empty_state.dart · bus_more_count.dart
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
├── android/
│   ├── app/
│   │   ├── build.gradle.kts            # release 서명·R8·desugaring
│   │   ├── proguard-rules.pro          # Gson 리플렉션 보호 (알림 재예약 · 기기 캘린더)
│   │   └── src/main/res/raw/keep.xml   # 리소스 축소로부터 ic_notification 보존
│   ├── fastlane/
│   │   ├── Appfile                     # package_name + json_key_file(~/.google_play/planroutine.json)
│   │   └── Fastfile                    # check_tago_key/check_play_key/build_aab/bootstrap/beta 5개 레인
│   ├── Gemfile (+ Gemfile.lock)        # fastlane 고정 (iOS와 같은 Ruby 환경 규칙)
│   └── bin/fastlane.sh                 # Homebrew Ruby 경로 주입 wrapper (iOS와 동일 패턴)
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
- **완료 도장**(`설정 > 완료 도장`): 모양 4종(완료 원형·결재 사각·판다·도마뱀) +
  "이미 찍은 도장 흐리게"(기본 ON). 흐리게는 **지난 도장에만** 적용 —
  `TodayEventRow._stampedOnEntry`로 구분하고 방금 누른 도장은 진하게 남긴다.
  - **모양은 설정 화면이 아니라 시트에서 고른다**(`StampStyleSheet`, 2열 그리드).
    설정 탭에는 `도장 모양 … 판다 ›` 한 줄만 남는다. 칩 `Wrap`으로 두던 시절 4종이
    되자 라벨 옆에 못 들어가 줄이 둘로 갈라졌고, 같은 화면의 `화면 테마`는 한 줄이라
    **한 화면에 행 문법이 두 종류**가 됐다. 규칙이 이렇게 바뀌었다 —
    **개수가 고정된 설정은 세그먼트, 늘어나는 설정은 시트.** 5번째 도장이 들어와도
    시트만 한 줄 자라고 설정 화면은 변하지 않는다.
  - 시트의 미리보기는 **`CompletionSeal`을 그대로 쓴다** — 전용 위젯을 새로 그리면
    실제 찍히는 도장과 어긋난다. 선택 표시는 골드 테두리·배경 **+ 체크 아이콘**이다
    (색만으로 두지 않는다). 선택지를 찾을 때는 `StampStyleSheet.optionKey(style)`를
    쓴다 — 글자 도장은 미리보기 **안에도** 같은 글자를 그려 `find.text`가 둘을 문다.
    가드는 `SealStyle.values`를 순회해 새 모양을 시트에 빠뜨리는 것을 막는다.
  - 모양 규칙은 `SealStyle`(`isSquare`) + **`SealMark` enum**(`text`/`panda`/`gecko`)이
    들고 있고 위젯은 `switch (style.mark)`만 본다. **불린 여러 개로 두지 않는다** —
    `usesIcon` 같은 불린은 둘 다 true인 상태를 타입으로 허용하고, 모양을 추가할 때
    분기를 빠뜨려도 컴파일이 통과해 새 도장이 조용히 글자로 그려진다.
  - 글자 도장의 문구는 44px 안에 들어가야 한다(내부 폭 31.4). 영문 4글자('Good')는
    13px에서 50px로 물리적으로 안 맞아 **글자 도장으로 못 만든다** — 가드가 폭을 지킨다.
    (그 문제로 없앤 `좋아요`(엄지 아이콘) 자리에 판다·도마뱀이 들어왔다. 없어진 모양을
    고른 사용자의 저장값은 `_decodeStyle`이 기본값으로 폴백한다.)
  - **그림 마크는 두 방식이 공존한다.** 판다는 `CustomPainter`(`SealPandaMark`),
    도마뱀은 **PNG 알파 마스크**(`SealGeckoMark` + `assets/images/seal_gecko.png`).
    - 마크를 손으로 그려야 했던 이유는 하나뿐이었다 — 테마에 따라 색이 바뀐다. 그래서
      "PNG는 색을 못 입혀서 안 된다"고 판단했는데 **틀렸다**: 알파 채널만 쓰고
      `color` + `colorBlendMode: BlendMode.srcIn`으로 입히면 팔레트를 그대로 따라간다.
      에셋은 **모양만** 담는다. 진짜로 안 되는 것은 이모지(`🦎`) 하나다.
    - 얼굴 하나(판다)는 원·타원 몇 개로 되지만, 다리 넷·발가락·말린 꼬리가 있는 실루엣
      (도마뱀)은 44px에서 손으로 못 맞췄다(여섯 번 시도해 전부 애벌레·튜브로 읽혔다).
      **그림을 마스크로 쓰면 그 문제가 없다** — 새 마크는 이 경로를 먼저 고려할 것.
    - 에셋 규칙: 알파 램프로 마스크를 뽑고 **선을 굵힌 뒤**(원본 선폭이 내용 폭의 3.7%면
      마크 28px에서 1px 미만이 돼 흐린 회색으로 뭉갠다) 112px 한 장으로 둔다.
      2.0x/3.0x 변형 폴더는 만들지 않는다(마크가 28px 고정이라 3배에서도 84px).
    - 마크 크기는 판다 22 / 도마뱀 28로 다르다 — 속 빈 윤곽선은 22에서 선이 사라진다.
      둘 다 `CompletionSeal.innerWidth`(31.4) 이하여야 하고 가드가 지킨다.
    - 도마뱀 에셋의 출처는 **정리됐다** — 사용자가 직접 편집한 그림이라 그대로 쓴다
      (사용자 확인, 2026-07-30). 이전에 걸어 둔 "App Store 제출 전 교체" 조건은 해제한다.
  - `test/tools/seal_preview.dart`가 4종을 **실제 위젯으로** 렌더해 PNG로 뽑는다
    (다크/라이트 각각 1x·3x). 에셋 마크는 위젯 존재 검증만으로는 못 지킨다 —
    파일이나 pubspec 선언이 빠져도 트리에는 `Image`가 그대로 있어 테스트가 통과하고
    **런타임에만** 빈 자리가 된다. 가드는 `rootBundle`로 실제 로드까지 확인한다.

### Google Calendar 연동 (**iOS 전용**)
- `google_sign_in`으로 `authHeaders` 획득 → 커스텀 `http.BaseClient`로 `googleapis` 호출.
- 단방향(생성만) — 수정/삭제 동기화 없음 (개인정보 최소 노출).
- GCP OAuth client는 "테스트" 모드, 테스트 사용자 수동 등록 필요. App Store 출시 시 verification 필요.

#### 안드로이드에서는 이 선택지를 제공하지 않는다 (2026-08-03)

**안드로이드의 "기기 캘린더"가 이미 구글 캘린더다.** `CalendarContract`에 쓰면 동기화된
구글 계정 캘린더로 들어간다(실측: 저장한 이벤트가 `account_type=com.google`인 캘린더에
들어갔다). 즉 REST API 경로는 **같은 곳에 두 번 가는 중복**인데, 값은 GCP Android OAuth
클라이언트 등록 + 동의 화면 검증이다. 등록이 없으면 사용자에게는
`ApiException: 10`(DEVELOPER_ERROR)로만 보인다(실측).

iOS는 정반대다 — EventKit은 iCloud/로컬이라 **구글로 가는 유일한 길**이 이 경로다.
그래서 지우지 않고 플랫폼으로 가린다.

- **판정은 `googleTargetSupportedProvider` 한 곳뿐이다**(`calendar_target_provider.dart`).
  설정 선택지와 스와이프 분기가 같은 값을 봐야 한다 — UI만 감췄더니 저장돼 있던
  `google` 값 때문에 **고를 수는 없는데 스와이프는 계속 Google로 가는** 막다른 길이
  남았다(`calendar_screen.dart`가 target으로 분기한다).
- `CalendarTargetNotifier.build()`가 지원하지 않는 플랫폼의 저장값을 `none`으로 **낮춘다**.
  저장값 자체는 지우지 않는다 — 그래야 지원되는 플랫폼에서 선택이 살아난다.
- ⚠️ `defaultTargetPlatform`이 아니라 `dart:io`의 `Platform.isAndroid`를 쓴다(리포 규칙).
  `Platform.isAndroid`는 위젯 테스트로 못 밟으므로 **provider로 감싸** override 가능하게 뒀다.
- 남은 문제: `_resolveDefaultCalendarId`는 `isDefault`(= `IS_PRIMARY`)인 첫 캘린더를 집는데,
  **구글 계정이 둘이면 primary도 둘**이라 먼저 온 쪽이 이긴다(실측: 학교 계정으로 들어갔다).
  계정이 하나면 정확하다. 기기 저장이 안드로이드의 유일한 경로가 됐으니 계정이 여럿인
  사용자에게는 남아 있는 문제다.

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
- **성격 카드는 한 줄이다** — 아이콘 + 종류 세그먼트 + ★ + 중요 스위치가 한 테두리 안
  같은 행에 들어간다. 원래는 세그먼트 행 / `Divider` / 스위치 행으로 **세 줄**이었는데,
  키보드가 올라오면 시트가 화면을 다 쓰고 그 뒤로는 저장·취소가 스크롤 밖으로 밀려
  합쳤다(실측: 키보드 380dp에서 35dp 가림 → 합친 뒤 보임).
  - **`SegmentedSettingRow`를 쓰지 않는다** — 그 위젯은 `아이콘 + 라벨 + 세그먼트`로
    한 행을 다 쓰는 구조라 스위치를 얹을 자리가 없다. 여기서만 직접 조립한다
    (세그먼트 채움 색 규칙은 그 위젯과 같은 값으로 맞춰 둔다).
  - **`종류` 글자를 뺐다** — 세그먼트가 `업무`/`행사`라 스스로 설명하고, 320pt 폭에서
    글자까지 넣으면 넘친다.
  - **중요 표시는 `Switch`가 아니라 이름을 담은 토글 칩이다**(`[★ 중요]`).
    별 + 스위치였을 때는 글자가 없어 **무슨 스위치인지 알 수 없었고**(사용자 신고
    2026-08-07), 별이 상태와 무관하게 늘 골드라 **꺼져 있어도 켜진 것처럼** 보였다.
    - 칩으로 바꾸면 이름이 들어가면서 **오히려 좁아진다**(실측 84 → 72dp) — 스위치가
      먹던 폭을 회수하기 때문이다. 라벨을 뺐던 이유가 폭이었으므로 그 제약이 풀렸다.
    - 상태는 **채움과 별 모양 두 겹**으로 말한다(`goldFill`+`onGold`+채운 별 /
      투명+테두리+빈 별). 색만으로 두지 않는 것은 도장 시트가 선택 표시에 체크
      아이콘을 함께 넣은 것과 같은 규칙이다.
    - 라벨은 `importantBadge`(`중요`), 스크린리더 이름은 `importantLabel`(`중요 표시`).
      `Semantics`에 **`excludeSemantics: true`가 필요하다** — 칩 안 `중요` 텍스트가
      자기 노드를 만들어 부모 라벨을 덮으면 `중요 표시`가 읽히지 않는다(가드가 잡았다).
    - ⚠️ **오늘 탭 경로는 여전히 `SwitchListTile`이다**(`allowKindChange: false`).
      거기는 전용 행이라 폭이 넉넉하고 글자 라벨이 이미 붙어 있다. 그래서 전역
      `switchTheme` 색 가드도 **그 경로로** 검사한다 — 캘린더 경로에는 스위치가 없다.
  - **오늘 탭 경로(`allowKindChange: false`)는 예전 그대로** 중요 스위치 한 줄
    (`SwitchListTile`, 글자 라벨 유지)이다 — 거기는 원래 두 줄이라 문제가 없었다.
  - 가드는 `event_edit_dialog_compact_test.dart`. **320·390·430pt를 훑어** 넘침을 보고,
    종류와 중요의 세로 중심이 겹치는지로 "한 줄"을 검사한다.
  - ⚠️ **구조적 해결이 아니다.** 버튼이 여전히 `SingleChildScrollView` 안에 있어
    임계값만 올라갔다(키보드 ~340dp → ~400dp. 420dp에서는 26dp 가린다). 다시 깨지면
    다음 수순은 **버튼을 스크롤 밖 고정 푸터로 빼는 것**이다.
- **종료 날짜 입력은 없다.** `getEventsByDateRange`가 `event_date`만 보므로 기간은 앱 안에서
  아무 일도 하지 않았다(3일짜리도 시작일 하루에만 점이 찍힌다). 실효는 Google/기기 캘린더로
  기간 이벤트를 내보낼 때뿐이라 **DB 컬럼·모델·내보내기 경로는 그대로 두고 입력만** 없앴다.
  회수한 48+8px은 설명칸이 가져갔다.
- 중요 표시는 **두 종류 모두에서** 유지한다 — 캘린더 ★ 강조는 학교 행사에도 의미가 있다.

#### 키보드 여백은 `math.max(0, viewInsets.bottom)` — 음수를 걸러낸다

두 편집 시트(`event_edit_dialog`·`schedule_edit_sheet`)는 아래 여백을 이렇게 준다.

```dart
Padding(
  padding: EdgeInsets.only(
    bottom: math.max(0, MediaQuery.viewInsetsOf(context).bottom),
  ),
  ...
```

**`max(0, ...)`가 장식이 아니다.** 3.41.6에서 한 번, 플랫폼이 음수 인셋을 보고해
`RenderPadding.padding`의 `value.isNonNegative` assert가 터지고 앱이 빨간 화면으로 갔다
(그 뒤 `referenceBox.attached`·`Duplicate GlobalKey`·`_dependents.isEmpty`가 연달아 무너졌다).
여백 값의 출처는 `viewInsetsOf(...).bottom` 하나뿐이므로 **그 순간 음수가 왔다**는 결론이 나온다.

- **왜 음수가 오는지는 모른다.** 업스트림에 음수 사례는 문서화돼 있지 않고, 빠른 개폐 중
  값이 틀리는 계열만 실재한다(flutter/flutter#163502). 그래서 원인이 아니라 **증상을 막는다.**
- 가드는 `event_edit_dialog_negative_inset_test.dart`·
  `schedule_edit_sheet_negative_inset_test.dart` 둘. 음수 인셋을 주입해
  **예외가 없고 시트가 살아 있는지** 본다. `max(0, ...)`를 지우면 두 건이 곧바로 깨진다(확인함).

##### 여기 있었던 `KeyboardInset`을 없앤 이유 (2026-08-03)

포커스를 옮길 때 키보드가 내려갔다 올라오며 시트가 통째로 흔들렸다(실측 진폭 334.8,
인셋 `335 → 6 → 335`). 원인은 iOS 고유 동작이 아니라 **Flutter 3.41.0에서 유입된 엔진
회귀**였다(flutter/flutter#184875 — Affected `3.41.0 → 3.41.6` / Not affected `3.38.10`).
`KeyboardInset`은 그 붕괴를 시트가 따라가지 않게 붙들던 100줄 workaround였다.

flutter/flutter#182661이 엔진에서 고쳤고 3.44.8에 들어 있다. 3.44.8 실측(기기 녹화
40ms 간격 248프레임): 전환 3회 동안 키보드 상단 경계가 `1442px`에 고정, **변화 0px**
(대조군인 시트 닫기에서는 같은 측정기가 `1442 → 2069px`를 잡아 감도를 증명했다).
흡수할 붕괴가 없어졌으므로 위젯과 가드 셋(유예 200ms·포커스 해제·뒤로 키)을 함께 지웠다.

**잃은 것을 적어 둔다** — 그 가드 다섯은 인셋 시퀀스를 직접 주입해 SDK와 무관하게
통과했으므로, 3.41.x로 되돌아가면 시트 흔들림을 **아무것도 잡아주지 않는다.** 리포에
버전 고정 장치가 없다는 점(기술 스택 표 참고)이 이 결정의 유일한 위험이다.

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
| 캘린더 | 외부 캘린더 저장 | 완료 토글 |
- 각 탭 상단에 2줄 안내 바 (SharedPreferences로 영구 닫기 가능).
- 오른쪽 스와이프의 **행선지는 `calendarTargetProvider`가 정한다**(Google / 기기 / 없음).
  안내 바 문구도 따라 바뀐다(`기기 저장`). 안드로이드에서는 Google이 선택지에서
  빠지므로 사실상 `기기 저장`이다.

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
- **섹션 8개**: 화면 · 완료 도장 · 버스 도착 · 내보내기 · 캘린더 연동(flag) · 알림 ·
  휴지통 · 데이터 관리 · 앱 정보.
- **깊은 설정은 화면 밖으로 뺀다.** 섹션이 열 개·행이 열아홉 개가 되자(스크롤 세 화면 반)
  무거운 둘만 빼서 12행으로 줄였다 — 도장 모양은 시트, 버스는 상세 화면.
  - **버스가 시트가 아니라 화면인 이유**: 그 안에서 정류장 검색(`/bus/stops`, 풀스크린)과
    `showTimePicker`를 다시 띄운다. 시트 위에 풀스크린을 push하면 시트가 가려진 채 뒤에
    남고 돌아올 때 다시 나타난다. 화면이면 `설정 › 버스 도착 › 정류장 검색`으로 쌓이고
    뒤로가기 한 번씩이 순서대로 맞는다.
  - `BusSettingsScreen`은 `features/bus/`가 아니라 **settings 아래** 산다. 본문 위젯
    (`BusSettingsTiles`)이 이미 여기 있어, bus에 두면 **bus → settings 역방향 import**가
    생긴다(지금은 settings → bus 한 방향). 위젯을 옮기지 않아 그 테스트 9건도 그대로다.
  - 설정 탭에 남는 요약은 순수 함수 `buildBusSettingsSummary`가 만든다
    (`꺼짐` / `켜짐 · 정류장 없음` / `켜짐 · N곳`). **정류장 이름을 넣지 않는다** —
    `우방아파트→중앙공원`은 320pt에서 넘친다. **켜짐 여부를 정류장 수보다 먼저 본다**:
    꺼 둔 설정에도 정류장은 남아 있어, 수를 먼저 보면 꺼진 기능이 켜진 것처럼 읽힌다.
  - 섹션 부제(`오늘 탭 맨 위에 출퇴근 버스 도착시간을…`)는 **상세 화면 상단으로 옮겼다.**
    처음 쓰는 사람에게 이 한 줄이 기능 소개다 — 섹션을 줄이면서 그냥 걷어내면 사라진다.
- **`AI 자동화 (고급)` 섹션은 없앴다**(2026-07-30). `aiTaskShareEnabledProvider`와
  `event_edit_dialog`의 분기는 **남겨 뒀다** — provider까지 지우면 되살릴 때 저장값을
  버린다. ⚠️ 토글이 켜진 채로 섹션을 지우면 다이얼로그가 계속 watch해 **끌 방법이
  없어진다**(기본값 `false`, 제거 전 꺼져 있음을 확인했다).

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

### 출퇴근 버스 도착 카드

- **DB를 쓰지 않는다.** 설정은 `shared_preferences`의 `bus_settings_v1` 하나, 조회 결과는
  메모리 캐시(30초)뿐이다. 자체 서버도 없다 — 기기에서 공공데이터포털을 직접 부른다.
  이것이 처리방침 §5·§6의 근거이므로 프록시를 세우려면 그 문서부터 고쳐야 한다.
- **인증키는 빌드 시 주입한다**(`--dart-define-from-file=<tmp>.json`, `ios/fastlane/Fastfile`).
  `--dart-define=TAGO_KEY=…`로 넣지 않는다 — fastlane의 `sh`가 명령 문자열을 echo하므로
  argv에 실으면 매 beta 로그에 키가 평문으로 남는다. 빌드 후 `strip_dart_defines`가
  `ios/Flutter/Generated.xcconfig`·`flutter_export_environment.sh`를 지운다(키가 재기록된다).
  키만 확인하려면 `./ios/bin/fastlane.sh check_tago_key`.

#### 실측 정류장 이름은 익명 라벨로 적는다

주석·문서의 `A정류장`·`B정류장`·`C시`·`D시`는 **실제로 조회한 수도권 정류장·시**를
가린 라벨이다(가상의 예시가 아니다 — 숫자는 전부 실측값이다).

개발자가 실제로 등록해 쓰는 정류장이라 이름을 그대로 적으면 **생활 반경이 드러난다**
(사용자 신고 2026-07-30). 화면에 박히는 예시도 같은 이유로 서울 공공 랜드마크
(`02004` 서울역버스환승센터)를 쓴다. 새 실측을 적을 때도 이 규칙을 따를 것.

`test/fixtures/gbis/`의 파일과 그 안의 응답은 **실측 원본이라 손대지 않는다** — 거기
남은 지명은 픽스처를 다시 뜨지 않는 한 그대로다(의도된 예외).

#### 소스는 지역으로 갈린다 — 접두가 라우팅이다

`BusStop.nodeId`의 접두가 "어느 지역이냐"가 아니라 **"어디에 물어볼 것이냐"** 를 뜻한다
(`BusApiClient._arrivals`가 이 접두로 분기한다).

| 지역 | 소스 | 접두 | 근거(실측) |
|---|---|---|---|
| 경기 | GBIS | `GGB` | TAGO의 `cityCode`는 정류장 소속이 아니라 **노선 운영 시·군 필터**라 같은 nodeId를 시·군마다 다르게 답한다(`GGB225000100`: C시 `3030·6501` / D시 `15·11-5·87`). TAGO 도시목록 138개에 **서울이 없어** 서울 노선(`5623·541`)은 영구히 안 나온다 |
| 인천 | TAGO | `ICB` | **정반대다.** 인천 A정류장에서 TAGO 7개(`5·5-1·46·516·517·518·519`) vs GBIS 1개(`5`) — GBIS는 경기 버스가 지나는 인천 정류소만 얇게 안다 |
| 서울 | GBIS | `GGB` | 옮길 곳이 없다(TAGO에 서울 없음). **부분 목록이라 확인 시트가 사용자에게 알린다**(`confirmSeoulPartial`). 응암역.신사오거리는 1개만 나온다 |
| 그 밖 | TAGO | `BSB`·`JEB` 등 | GBIS는 수도권 전용 |

- **규칙**: 각 소스가 **자기 관할 밖을 얇게만 안다.** 같은 정류장을 두 소스가 다르게
  아는 것이 아니다. 새 지역을 붙일 때는 그 지역에서 **양쪽을 실측 비교**하고 결정한다.
- `TAGO nodeId` = 지역접두 + `GBIS stationId`(경기·인천 모두 실측 확인). 그래서 접두만
  갈아 끼우면 소스가 바뀐다 — 마이그레이션이 없다.
- 서울 전용 API를 붙이면 필요한 것은 **`서울특별시_정류소정보조회` 하나**다: 검색
  `getStationByNameList` · 경유노선 `getRouteByStationList` · 도착정보
  `getStationByUidItem`. `버스도착정보조회` 서비스에는 정류소 단위 전체 조회가 **없다**
  (저상·노선별만). 남은 비용은 **ATS 예외** 하나 — `ws.bus.go.kr`이 http 전용이다(실측).

#### 선택 목록은 경유노선에서 나온다 (도착정보가 아니다)

- 확인 시트의 "타는 버스만 남겨주세요"는 `getBusStationViaRouteListv2`(경유노선)로 만든다.
  **도착정보로 만들면 등록하는 시각이 고를 수 있는 노선을 결정한다** — 경기 A정류장는
  경유노선 10개인데 그 순간 도착정보가 있는 것은 8개였고 실기기에서는 2개만 보였다
  (사용자 신고, 2026-07-29). 경유노선은 시각과 무관해 심야에 등록해도 같은 목록이다.
- 도착정보는 목록이 아니라 **각 행의 장식**(남은 분)이다. 없으면 그 자리를 비운다 —
  `0`(곧 도착)과 `null`(정보 없음)은 다르다.
- **행선지**(`routeDestName`)를 부제로 보여준다. 길 양쪽 정류장은 이름도 번호도 같고
  행선지만 다르다(`3030 → 신사역(중)`) — 이 시트가 방향을 확인시키는 화면인데 노선번호만
  으로는 "여기 온다"까지만 알 수 있다.
- 표시 순서는 `buildRouteChoices`가 **번호순**으로 정한다(파서는 정렬하지 않는다). 카드는
  빠른 순, 시트는 번호순 — 목적이 다르다. API 순서로는 `3030`이 맨 위, `6`이 아홉 번째다.
- 경유노선이 비면(비수도권·조회 실패) 도착정보로 목록을 만든다 — 이전 동작으로 정확히 폴백.

#### 검색은 이름만으로 (도시 선택은 보조)

- 주 경로는 GBIS `getBusStationListv2` — **도시코드가 필요 없다.** 이름만으로 서울·경기·인천을
  한 번에 답한다(`강남역` → 서울 16건). TAGO 검색은 `cityCode`가 필수라 전국 138개 도시
  칩을 먼저 보여줘야 했다.
- **도시 목록은 지역 모드에 들어갈 때만 부른다.** 화면 진입마다 부르면 주 경로가 TAGO 응답
  속도에 묶인다(실측 5.1s, 클라이언트 타임아웃 10s — 실제로 통합 테스트가 여기서 멈췄다).
- **자동 폴백이 아니라 명시적 전환이다.** "GBIS가 0건이면 TAGO로"는 성립하지 않는다 —
  부산 사용자가 `서면`을 찾으면 GBIS가 서울·광명·인천의 `강서면허시험장` 등 12건을 주므로
  0건이 아니다. `다른 지역에서 찾기` 링크로 도시 선택을 펼치고, 그때는 TAGO로만 찾는다.
  링크는 **검색 전 화면에도** 둔다(결과 뒤에만 두면 헛검색을 한 번 해야 도달한다).
- **`BusStop.regionName`은 선택이 아니라 필수다.** `A정류장`는 경기 3개 시·인천·서울에
  다 있고 이름도 정류소번호도 사람이 구별에 쓸 수 없다. 도시를 먼저 고르던 시절에는 그
  정보가 화면 위쪽에 이미 있었다 — **단계를 지우는 변경은 그 단계가 조용히 제공하던 정보를
  함께 지운다.** 결과 행 부제(`서울 · 02004`)와 저장에 둔다.
- `mobileNo`는 앞에 공백이 붙어 온다(`" 26044"`). Dart의 `int.tryParse`는 공백을 허용하지
  않아 trim이 없으면 정류소번호가 전부 0이 된다.

#### GBIS 응답의 함정

- **건수가 1이면 배열이 아니라 객체로 온다**(실측 강남역10번출구: 경유노선 `9711` 하나 →
  객체 / 강남역12번출구는 2건 → 배열). 이 분기가 없으면 **노선이 하나뿐인 정류장이 통째로
  고장난다** — 빈 목록 → `empty` → 카드는 `오늘 운행이 끝났어요`, 시트는 `오는 버스가
  없어요`인데 실제로는 버스가 오고 있다.
- 같은 필드가 `int`·`''`·키 없음으로 **섞여** 온다. `routeName`은 `9`(int)와 `'11-5'`(String)가
  한 응답에 있어 `as String` 캐스트가 크래시한다. 빈 값을 0으로 뭉개면 도착 정보가 없는
  노선이 `곧 도착`으로 맨 위에 올라온다.
- 초가 있으면 초를 쓴다 — 같은 행의 분 필드보다 정확하다(`predictTimeSec1 361`인 버스의
  `predictTime1`이 `5`).
- **픽스처는 실측 응답을 저장해 쓴다**(`test/fixtures/gbis/`). 손으로 쓴 GBIS 픽스처가 현실과
  달라 여러 번 어긋났다.

#### 데이터 출처 표시는 가드가 지킨다

- 서울 API의 이용허락범위가 `저작자표시`(CC BY) + 공공누리 제1유형이라 **출처 표시가
  라이선스 의무다**. `설정 › 앱 정보`의 `DataSourceListTile`.
- 가드는 렌더링이 아니라 **문구와 실제 호출의 일치**를 본다
  (`test/features/settings/data_source_credit_test.dart`). `bus_api_client.dart`의 기관코드
  (`1613000`·`6410000`)와 호스트(`ws.bus.go.kr`)를 읽어 **양방향**으로 검사한다 — 호출하는데
  안 적혀 있으면 실패, 적혀 있는데 호출하지 않으면 실패. 소스를 추가하고 출처를 잊는
  순간이 정확히 라이선스를 어기는 순간이다.

##### 출처 의무는 **두 곳**이다 — 앱 안과 스토어 설명 (2026-08-04 실측)

Play가 `versionCode 143`을 **정책 위반으로 거부했다.**

```
발견된 문제: 혼동을 야기하는 주장 관련 정책 위반
  정부 정보의 출처 링크 누락
문제 세부정보 → 자세한 설명 (ko-KR): "Missing Source Link for Government Information"
```

앱 안의 `DataSourceListTile`은 기관 이름을 적고 있었지만 **URL이 없었고, 스토어 설명에는
출처가 기관 이름만 있었다.** Play는 정부 정보를 표시하는 앱에 두 가지를 요구한다 —
**① 유효하고 정상 작동하는 출처 URL을 앱 설명에 명시 ② 정부 기관을 대표하지 않는다는
면책조항을 앱 설명에 표시.** 제휴 여부와 무관하게 적용된다.

- 지적 영역은 `자세한 설명 (ko-KR)` **한 곳**이었다 — 바이너리는 무관하므로 **새 빌드가
  필요 없다.** AAB를 다시 만들지 말고 스토어 등록정보만 고쳐 재검토를 요청한다.
- 문안은 `docs/play_store_description.md`가 단일 원본이다. `■ 정보 출처와 면책조항`
  섹션에 앱이 호출하는 데이터셋 URL 넷 + 포털 + 공휴일 근거 법령을 적었다(전부 200 확인).
- ⚠️ **에듀파인은 링크하지 않는다.** 앱은 에듀파인에 접속하지 않고 사용자가 고른 사용자
  본인의 파일을 읽을 뿐이다. 링크를 붙이면 "정부 시스템과 연동된다"는 오해를 만들어
  **같은 정책을 더 위반하는 쪽**으로 간다. 대신 무관함을 문장으로 적는다.
- ⚠️ **앱 이름이 `공직플랜`이라 정부 앱으로 오인될 여지가 있다** — 면책조항을 지우면
  그 위험이 되살아난다. 도입부와 전용 섹션 두 곳에 둔 것은 "쉽게 확인할 수 있도록"
  요건 때문이다.
- **iOS 설명(`docs/app_store_description.md`)에도 들어갔다** — 면책조항 두 문장 + 같은
  URL 여섯 개. 그 문서의 `## 1.3.0에서 고친 것`이 경위를 적고 있다. (이 칸은 한동안
  "iOS에는 없다 — 다음 제출 때 넣을 것"으로 남아 있었다. **이미 갚은 부채를 미결로
  적어둔 문서가 사람의 기억보다 오래 산다** — 그래서 아래 가드로 올렸다.)
- **가드가 생겼다**: `test/deploy/store_listing_credit_test.dart` 6건.
  `data_source_credit_test.dart`는 **앱 안 문구**만 보고, 이 가드는 **스토어 등록정보**를
  본다 — 거부 당시 지적된 영역이 `자세한 설명 (ko-KR)` 한 곳이었는데 어떤 테스트도 그
  파일을 보지 않았다. 검사하는 것: 면책 주장 셋 · 데이터셋 URL 넷 + 포털 + 법령 ·
  **두 문서의 URL 집합 일치**(한쪽만 고친 상태를 잡는다) · 기관 표 ↔ 실제 호출 양방향.
  - 기관 표는 `test/helpers/data_source_agencies.dart` **한 곳**에 있다. 두 가드가 같은
    표를 봐야 한다 — 한쪽에만 기관을 추가하면 다른 쪽이 조용히 검사를 빠뜨린다.
  - ⚠️ 절을 자를 때 **첫 등장만** 쓴다. `app_store_description.md`는 변경 이력 표에서
    같은 절 제목을 한 번 더 쓴다 — 마지막 등장을 잡으면 절이 아니라 표를 검사한다
    (회귀를 심어 확인함: 그 상태에서 URL이 하나도 없다).
  - **URL이 지금도 200인지는 검사하지 않는다**(네트워크). 그 몫은 가드가 아니라 스킬이다.

#### 조회 간격은 도착 시점을 겨냥한다

`busPollIntervalFor(view)` (`bus/domain/bus_poll_interval.dart`) — **순수 함수**.

```
① state == closed (막차 확정)  → null (조회 중단)
② 목록이 비었지만 막차는 아님   → 300초
③ 그 밖                        → min(300초, 1차 남은시간 + 30초)
```

**왜 균등 간격이 아닌가**: 1초 보간이 들어온 뒤로 서버가 "5분"이라 하면 그 5분을 요청
없이 그릴 수 있다. 조회가 새로 가져오는 것은 **예측 수정**과 **목록 교체** 둘뿐이고,
후자는 맨 앞 버스가 지나가는 순간에 몰려 있다.

- **`1차+30초` 상한이 급소다.** 없으면 간격이 배차보다 길어져 지나간 버스의 카운트다운이
  화면에 남는다(`arrSec`은 0에서 멈춘다) — `곧 도착`이 몇 분씩 붙박이가 되고 진짜 다음
  차는 안 보인다. 시뮬에서 drift 0인데도 오차 p90 168초가 나온 게 이것이다.
- **①의 기준은 `visible.isEmpty`가 아니라 `state == closed`다.** 목록은 조회 실패·키
  오류·필터로도 빈다. 비었다고 멈추면 **일시적 네트워크 오류에 카드가 영구히 얼어붙는다.**
- **`busPollMax`(300초) < `busMaxDisplayAge`(6분)** 여야 한다. 어기면 먼 버스 구간에서
  목록이 사라졌다 돌아오며 깜빡인다. 가드가 이 부등식을 잡는다.
- `Timer.periodic`이 아니라 매번 재계산하는 `Timer`다. **`??=` 관용구를 그대로 쓰면**
  만료된 핸들이 non-null로 남아 폴링이 한 번 돌고 영영 멈춘다.
- `build`와 `_tick`은 `_viewOf` **하나**를 쓴다 — 각자 조립하면 간격이 사용자가 보는
  목록과 어긋나 상한의 전제가 깨진다.

**서버 예측은 30초 사이에 중앙값 33초씩 수정된다**(실측 2026-07-30, 서울역
버스환승센터 25분·420쌍). 상대 오차 **16.2%** — 이 값이 "2차로 로컬 굴리기"를
확정 기각시킨다(6% 이하여야 성립). 폴링을 아무리 촘촘히 해도 이 흔들림은 남는다.

**규칙은 시뮬레이션이 정했다**(`test/tools/bus_poll_sim.py`). 상한 없는 안, 2차 도착으로
로컬 굴리기, 임박/대안 5분기 — 셋 다 기각했고 근거는
`docs/superpowers/specs/2026-07-30-bus-poll-interval-design.md`에 있다. 간격을 손볼 때는
상수 둘만 바꾸고 시뮬을 다시 돌려 볼 것.

⚠️ **시뮬은 실패를 모델링하지 않는다.** ①의 버그를 잡은 것은 기존 호스트 테스트였다.

#### 축의 점은 **차량**으로 묶는다 — 노선이 아니다

`BusBodyAxis.dotKeyFor(vehicleId ?? routeId)`.

애니메이션 키는 "이것이 무엇인가"를 선언하는 자리다. 점을 `routeId`로 묶었더니,
앞차가 지나가고 같은 노선의 뒤차가 1차가 되는 순간 Flutter는 **같은 점의 위치만
0분에서 8분으로 바뀐 것**으로 읽고 그 사이를 애니메이션했다 — 화면에는 버스가
시간을 거슬러 오른쪽으로 미끄러졌다(실기기 신고 2026-07-30).

축의 점은 노선이 아니라 **"지금 오고 있는 이 버스"** 다. GBIS의 `vehId1`/`vehId2`로
묶으면 지나간 차는 키가 사라져 제거되고, 뒤차는 **같은 키를 유지한 채** 속 빈 점에서
채운 점으로 바뀌며 제자리에 남는다.

- **점과 다음 점이 같은 키 이름공간을 쓴다.** 달랐다면 뒤차가 1차가 될 때 위젯이
  교체돼 그 자리에서 채워지는 대신 사라졌다 다시 생긴다.
- TAGO에는 차량 ID가 없어 `routeId`로 떨어진다. **그 경로(인천·비수도권)에는 증상이
  남는다** — 알고 두는 것이지 고쳐진 것이 아니다.
- 가드는 `bus_axis_rollover_test`. 키를 `routeId`로 되돌리면 3건이 깨진다(확인함).

**일반화**: `AnimatedPositioned`·`AnimatedSwitcher`처럼 키로 정체성을 잇는 위젯에서는
**목록의 항목이 교체되는 축**과 **키가 세는 축**이 같아야 한다. 다르면 교체가
이동으로 재생된다.

#### 정류장 이름은 길다 — `trailing`에 넣을 때 폭을 묶을 것

실측 `석수체육공원.자동차학원.원태우지사의거지`. 이런 이름이 실재한다.

**`ListTile`은 `trailing`에 폭 제약을 주지 않는다.** 긴 이름을 그대로 넣으면 가로를
다 먹고 `title`·`subtitle`에 두 글자 폭만 남는다 — 실기기에서 `도착지`가 세로로
여섯 줄, 부제가 일곱 줄이 됐다(2026-07-30).

**같은 함정을 두 번 밟았다.** 카드 제목줄(`bus_arrival_card`)은 이미 `Expanded` +
`ellipsis`로 막고 있었는데 설정 행(`bus_settings_tiles._slotTile`)만 빠져 있었다.
정류장 이름을 새 자리에 넣을 때는 **먼저 폭을 묶는다.**

- 설정 행은 `LayoutBuilder` + `ConstrainedBox(maxWidth: 폭 × 0.45)` + `ellipsis`.
- 45%인 이유는 남는 55%가 320pt에서 부제를 두 줄 안에 담기 때문이다. 더 조이면
  이번엔 정류장 이름이 두 글자만 남는다 — 양쪽이 서로를 밀어낸다.
- 가드는 `bus_slot_tile_long_name_test`가 **320·390·430pt를 훑는다.** 제목 한 줄,
  부제 두 줄까지. 폭 하나로만 재면 다른 폭에서 조용히 깨진다.

#### 확인 시트

- `useSafeArea: true`가 **필요하다.** 기본값(false)은 시트를 화면 top까지 뻗게 하고 그 모드에서는
  `MediaQuery`의 top padding이 제거돼 **시트 안의 `SafeArea`가 상단에 아무 일도 하지 않는다** —
  제목이 다이나믹 아일랜드와 겹쳐 읽히지 않았다. 시트 높이가 내용에 따라 변하므로 가드는
  **노선 10개** 픽스처를 쓴다(3개로 재면 시트가 짧아 통과한다).
- 재료가 **하나도 없을 때만** 저장을 막는다. 경유노선과 도착정보는 별개 호출이라 도착 시간이
  없어도 행선지로 방향을 확인할 수 있다 — 그것만으로 막으면 확인할 수 있는 사람을 막는다.
  반대로 둘 다 없으면 시트가 통과 도장이 되므로 그때는 막는다.

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
./ios/bin/fastlane.sh release build:115   # 빌드 승격 + 릴리즈 노트·설명·스크린샷 반영 (제출은 안 함)
./ios/bin/fastlane.sh withdraw_review     # 심사 철회 (편집 가능 상태로)
./ios/bin/fastlane.sh asc_state           # 심사 단계 + 선택된 빌드 + 스크린샷 장수 조회
./ios/bin/fastlane.sh check_builds  # 최근 빌드 processing_state 조회 (post-deploy)
./ios/bin/fastlane.sh check_tago_key      # TAGO 키 확인 (빌드·업로드 없음)

./android/bin/fastlane.sh check_tago_key   # TAGO 키 파일 확인 (빌드·업로드 없음)
./android/bin/fastlane.sh check_play_key   # 서비스 계정 JSON + client_email 검증 + 트랙 4개 versionCode 조회
./android/bin/fastlane.sh build_aab        # 가드 → clean → release AAB만 생성 (업로드하지 않는다)
./android/bin/fastlane.sh bootstrap        # build_aab + internal 트랙 draft 업로드 (패키지명 확정용, 최초 1회만)
./android/bin/fastlane.sh beta             # 가드 → versionCode → build_aab → 비공개 테스트(Alpha) 업로드
```
- Wrapper가 Homebrew Ruby(`/opt/homebrew/opt/ruby/bin`)를 PATH 앞에 주입해 `bundle exec fastlane`을 돌린다. 사용자 shell 설정은 건드리지 않는다.
- `ios/Gemfile`에 fastlane + cocoapods 고정. 최초 실행 시 wrapper가 자동으로 `bundle install`.
- beta의 build_number는 Fastfile이 `latest_testflight_build_number + 1`로 자동 계산. **iOS는 `pubspec.yaml`의 `+N`을 읽지 않는다** — `pubspec_version_name`이 `X.Y.Z`만 파싱하고 계산값을 `--build-number=`로 넘긴다.
- **`pubspec.yaml`의 `+N`은 안드로이드 전용 하한이다** (`next_version_code` = `max(하한, Play 트랙 최대 + 1)`). 한 필드가 두 플랫폼에서 **다른 뜻**을 갖는 것이 함정의 뿌리다 — iOS에서 무해하니 손으로 올려도 된다고 생각하면, **다음 안드로이드 업로드가 그 값으로 튀고 versionCode는 감소할 수 없다**(실제로 `+143`이 그렇게 들어왔다: Play가 54인데 다음 업로드가 143이 될 상태였다).
  - **두 스토어 번호를 맞추려면** 하한을 `TestFlight 최신 + 1`로 둔다. iOS는 스스로 그 값에 도달하고 안드로이드는 하한이 `Play최대+1`을 이겨 같은 번호가 된다 — **레인을 고칠 필요가 없다**(2026-08-03 실측: ASC `v142` · Play `54` → 양쪽 `143`).
  - **잊어도 깨지지 않는다** — 안드로이드는 자기 `Play최대+1`로 굴러가고 그때만 한 칸 어긋난다. 정렬은 릴리스 빈도 차이만큼 서서히 마모된다(iOS 142회 대 Android 54회가 그 누적이다).
  - ⚠️ 트랙 조회가 **전부** 실패하면 하한이 단독으로 결정한다(`Fastfile:178`). 이미 올린 번호가 하한이면 중복으로 거부되므로 그때 하한을 올린다.
- **release는 promote 전용 + 제출하지 않는다**: 재빌드/재업로드 없이 TestFlight 빌드를 `skip_binary_upload`로 승격하고, 버전 페이지 생성·릴리즈 노트 주입까지 한다. **최종 '심사를 위해 제출' 버튼은 사람이 ASC에서 누른다** (`submit:true`를 명시하면 자동 제출하지만 기본은 아님). 되돌리기 어려운 외부 작업이라 제출 직전에 눈으로 확인할 여지를 남긴다.
- ⚠️ **처리에서 거부된 빌드도 번호를 소비한다.** `latest_testflight_build_number`는
  `Build.all`에 나타나지 않는 거부된 빌드까지 본다(실측: `v143` 거부 뒤 다음 `beta`가
  `143 → 144`를 집었다). 그래서 **업로드 실패는 두 스토어 번호 정렬을 한 칸 깨뜨린다** —
  정렬을 유지하려면 실패한 쪽에 맞춰 다음 릴리스에서 하한을 다시 올려야 한다.
- **승격 대상은 `build:<N>`으로 못박을 것.** 미지정 시 최신을 집는데, 실기기 검증 후 `beta`를 한 번 더 돌렸다면 검증하지 않은 빌드가 올라간다.
- **빌드 연결은 레인이 `select_build`로 직접 한다** — deliver는 `submit_for_review: false`면 `build_number`를 받고도 빌드 선택을 건너뛴다(실측 v124: deliver 성공인데 선택 빌드는 v115 유지). 성공 신호는 로그의 `빌드 연결: vNN`이고, `asc_state`의 `선택된 빌드`로 교차 확인한다.
- **가드 4개**: A(버전>승인본) / B(빌드 VALID) / D(이미 심사 단계면 손대지 않음) / E(릴리즈 노트 존재). 버전 페이지는 없으면 자동 생성된다(minor·major에서는 항상 없다).
- **릴리즈 노트는 `docs/release_notes/<버전>.ko.txt`** — release가 읽어 ASC에 넣는다. 버전을 올리면 이 파일을 먼저 만든다.
- **beta 레인**은 시작 시 `reset_ios_caches`(flutter clean + Pods/build 제거)를 자동 실행 — 시뮬 슬라이스 함정(#6) 차단. clean 때문에 매 beta가 수 분 더 걸린다. release는 빌드가 없어 해당 없음.

#### 스크린샷에는 독립 레인이 없다 — `release`가 유일한 경로다

`ios/fastlane/screenshots/ko/`의 파일은 **`release`가 올린다**(`shots:false`로 건너뛸 수
있다). `dedupe_screenshots!`·`each_screenshot_set`은 Fastfile의 **함수**이고 레인이 아니다 —
`release`가 업로드 직후 부르고(`Fastfile:517`), `asc_state`가 장수를 셀 때 쓴다(`:652`).

- ⚠️ **`upload_screenshots`·`check_screenshots`·`dedupe_screenshots`라는 레인은 없다.**
  이 문서와 deploy 스킬 런북이 셋을 명령으로 적어두고 있었는데 실물에 없어, 스크린샷을
  확인하려던 세션이 `Could not find lane`으로 헛돌았다(2026-08-06). **실제 iOS 레인은
  일곱 개다**: `load_asc_api_key`·`check_tago_key`·`beta`·`release`·`withdraw_review`·
  `asc_state`·`check_builds`.
  - **이 함정은 가드로 올라갔다** — `test/deploy/fastlane_lane_docs_test.dart`가
    두 Fastfile의 `lane :`과 이 문서·런북의 `<platform>/bin/fastlane.sh <이름>`을
    **양방향** 대조한다(`data_source_credit_test.dart`와 같은 형태). 없는 명령을
    적으면 깨지고, 레인을 추가하고 문서에 안 적어도 깨진다(둘 다 회귀를 심어
    확인함). 내부 헬퍼는 `_internalLanes`로 면제하되 **이유를 함께 적는다** —
    면제 목록을 늘려 통과시키면 역방향 검사가 무력해진다.
  - 검사 대상은 **운영 문서 둘**(CLAUDE.md·deploy SKILL.md)이다.
    `docs/superpowers/specs/`는 특정 시점의 설계 기록이라 제외한다.
- **확인 수단은 `asc_state` 하나이고 장수만 알려준다**(`ko / APP_IPHONE_65 6장`).
  파일명·순서를 봐야 하면 ASC 웹에서 직접 본다. 그래서 "어느 장이 빠졌는지"는
  로컬에서 판정할 수 없다 — 아래 실측이 그 한계에 걸린 사례다.
- ⚠️ **제출 후 장수가 줄었다**(실측 2026-08-06): release 직후 `65 6장 / 67 6장`이었는데
  제출 뒤 조회에서 `65 5장 / 67 6장`이 됐다. 같은 실행의 dedupe가 `6.5_6_bus.png`를
  중복으로 지운 기록이 단서지만, **어느 장이 남았는지는 확인하지 못했다**(위 한계).
  스크린샷을 갈아치우려면 `withdraw_review`가 필요해 대기열 처음으로 돌아가므로,
  장수가 슬롯마다 달라도 **다음 릴리스에서 맞추는 편이 값싸다**.

### R8은 Gson을 쓰는 플러그인을 조용히 망가뜨린다 — release에서만

Gson은 **필드 이름을 리플렉션으로 읽어** JSON 키를 만들고 Dart는 그 이름으로 값을
찾는다. R8이 이름을 줄이면 키가 `a`/`b`가 되어 **Dart가 받는 값이 전부 null**이 된다.
컴파일도 통과하고 디버그도 멀쩡하다 — **release 빌드에서만** 깨진다.

이 리포는 같은 함정을 **두 번** 밟았고, Gson을 쓰는 안드로이드 플러그인은 지금
**둘뿐인데 둘 다 사고를 냈다**:

| 플러그인 | 증상 | 규칙 |
|---|---|---|
| `flutter_local_notifications` | 부팅 후 알림 재예약이 죽는다 | `-keepattributes Signature` + TypeToken keep + `@SerializedName` 필드 keep |
| `device_calendar` | 기기 캘린더 저장이 `저장 실패`로 끝난다 | `-keep class com.builttoroam.devicecalendar.models.** { *; }` |

- **device_calendar 실측(Galaxy A34, 2026-08-06)**: R8 매핑에서 수정 전
  `models.Event.eventTitle -> a`, `models.Calendar`는 **클래스 자체가 살아남지
  못했다**. 그래서 Dart의 `Calendar.isReadOnly`가 null이 되고
  `c.isReadOnly == false`가 거짓이라 **쓰기 가능한 캘린더가 0개**로 보였다 →
  `_resolveDefaultCalendarId`가 null → `writable 캘린더가 없습니다`.
  **삽입은 시도조차 되지 않았다**(이벤트 수 변화 0). 수정 후 전부 원래 이름 유지.
- ⚠️ **범용 `@SerializedName` 규칙으로는 안 걸린다** — device_calendar의 모델에는
  애노테이션이 없다. 플러그인이 `consumer-rules`를 제공하지 않으므로 **앱이 지킨다.**
- **가드**: `test/deploy/android_gson_proguard_test.dart`가 `.dart_tool/package_config.json`으로
  플러그인 안드로이드 소스를 훑어 Gson 사용을 찾고, 그 네임스페이스에 keep 규칙이
  있는지 검사한다. 없으면 실패한다(회귀를 심어 확인함). 범용 규칙으로 덮이는
  경우만 `_exempt`에 **이유와 함께** 등록한다.
- **단위 테스트로는 재현할 수 없다** — R8은 release에서만 돈다. 그래서 가드는
  재현이 아니라 **예방**(규칙 존재)을 검사한다. 실제 동작 확인은 아래 진단 빌드로 한다.

#### 진단용 축소 빌드를 스토어 앱 옆에 깐다

R8 전용 결함은 **축소된 빌드를 실기기에서 돌려야** 보인다. 그런데 로컬 release APK는
서명이 Play와 달라 그냥 설치하면 **스토어 앱을 지워야 하고 테스트 데이터가 날아간다.**

- **디버그**: `build.gradle.kts`의 debug 블록이 `applicationIdSuffix = ".debug"`를 준다 —
  `flutter run`이 스토어 앱을 건드리지 않는다. ⚠️ 이 변종은 Google 로그인이 안 된다
  (OAuth 클라이언트가 원래 패키지명에 묶여 있다). 안드로이드는 Google 연동을 감추므로
  실질 영향은 없다.
- **축소 확인용**: `applicationId`를 `com.planroutine.app.diag`로 **잠깐** 바꿔
  `flutter build apk --release --dart-define-from-file=<tago>.json` 하고 **곧바로 되돌린다.**
  커스텀 buildType이나 flavor를 만들지 않는다 — 전자는 Flutter가 `release`라는 이름에
  맞춰 축소를 켜므로 **정작 R8이 안 도는** 빌드가 나올 수 있고, 후자는 태스크 이름이
  바뀌어 fastlane 레인이 깨진다.
- 검증은 **R8 매핑 전/후 비교**(`build/app/outputs/mapping/release/mapping.txt`)와
  **실기기 동작** 둘 다 본다. 매핑만으로는 증상이 사라졌다는 증거가 안 된다.

### Android 알림은 M1까지 **구조적으로 죽어 있었다**

실기기 신고(Galaxy A34, 2026-08-08): 알림 스위치를 켜도 즉시 OFF로 되돌아간다.
버그가 아니라 **Android 경로를 아예 안 만든 상태**였다(`notification_service.dart`의
주석이 `구현은 iOS 한정으로 필요한 부분만`이라고 적고 있었다).

사망 지점이 **둘**이고, 둘 다 화면상 증상이 없어 오래 숨었다.

1. `InitializationSettings`에 `android:`가 없으면 플러그인이 **첫 줄에서
   `ArgumentError`를 던진다.** `main.dart`의 `try { … } catch (_) {}`가 먹어
   크래시하지 않고, `_initialized`가 안 켜지고 이어지는 `sync()`도 같은 catch에
   먹힌다 — **화면상 증상 0.**
2. `requestPermission()`이 iOS 플러그인만 resolve해 Android에선 늘 `false`.
   `setMaster(true)`가 그 false를 받고 마스터를 도로 끈다 → **스위치를 켤 수 없다.**

- **채널 id는 `*Strings`에 두지 않는다**(`notification_details.dart`의
  `kAndroidChannelId`). 한 번 만들면 importance·소리를 코드로 못 바꾸고, 바꾸려면
  id를 bump 해야 하는데 그러면 **채널이 갈라져 사용자 알림 설정이 초기화된다.**
  이름·설명은 `설정 › 앱 › 알림`에 노출되는 UI 문자열이라 `NotificationStrings`에 둔다.
- **채널을 `init()`에서 미리 만든다.** 안 만들어도 첫 발화 때 자동 생성되지만 그
  시점은 "예약할 때"가 아니라 "발화할 때"라, 그때까지 설정 화면에 채널이 없다.
- **`BigTextStyleInformation`이 필수다.** 본문이 두 줄인데(`오늘 …\n이번 주 …`)
  Android는 접힌 알림에서 한 줄만 보여준다 — 없으면 `이번 주`가 통째로 안 보인다.
  iOS는 여러 줄을 그대로 보여줘 이 차이가 안 드러났다.
- **스케줄 모드는 `inexactAllowWhileIdle`이고, 값 하나에 Play 심사가 달려 있다.**
  `exact*`는 `SCHEDULE_EXACT_ALARM` 고위험 권한 선언 양식 대상이다. 대가인 Doze
  9분 규칙은 이 앱에 무해하다 — `computeNotifications`가 발송 시각으로 병합해
  **하루 1건**만 만들기 때문이다(개별 이벤트마다 알림을 만드는 앱이었으면 이 결정이
  성립하지 않는다). ⚠️ 9분 규칙을 안 넘는 것이 **정시 발화를 뜻하지 않는다** —
  inexact alarm이라 지연 상한이 문서에 없다.
- ⚠️ **리시버가 둘이다.** `ScheduledNotificationBootReceiver`(부팅 재예약)만 넣으면
  안 된다 — **`ScheduledNotificationReceiver`가 없으면 재부팅과 무관하게 예약 알림이
  한 건도 발화하지 않는다.** 이름이 부팅용으로 읽혀 빠뜨리기 쉽다. 플러그인은 v16부터
  receiver를 하나도 선언하지 않는다(`POST_NOTIFICATIONS`·`VIBRATE`만 병합) —
  **`POST_NOTIFICATIONS`는 앱이 적을 필요가 없고, `RECEIVE_BOOT_COMPLETED`는 적어야 한다.**
- **아이콘은 `res/drawable/`이고 mipmap이 아니다.** 네이티브가
  `getIdentifier(name, "drawable", pkg)`로 찾고 defType이 고정이다. 테두리를 한
  path로 그리면 nonZero fillType 때문에 **상태바에 흰 사각형**이 뜬다 — 막대로 나눠 그린다.
  release는 리소스 축소가 기본 ON이라 `keep.xml`이 이 drawable을 지킨다.
- 가드는 `test/features/notifications/android_wiring_test.dart` 15건. 서비스가
  플러그인 인스턴스를 들고 있어 단위 테스트로 못 밟으므로 **값과 소스를 검사한다** —
  실제 동작은 에뮬레이터에서 확인했다(채널 생성 · 권한 다이얼로그 · 스위치 유지 ·
  `dumpsys notification`에 `channel=schedule_reminder` + `BigTextStyle` 발화).

### Android 레인

- **트랙은 값과 함께 기억할 것**: `beta` = 비공개 테스트(Play 콘솔 API identifier `alpha`,
  콘솔 화면 이름은 **`Alpha`/"비공개 테스트"**) / `bootstrap` = `internal`(draft, 패키지명
  확정용 1회성). ⚠️ **`internal`은 비공개 테스트 14일 요건을 하루도 세지 않는다** — 트랙을
  착각해 `internal`에 올리면 14일이 0일이 된다. 첫 `beta` 실행 후에는 **콘솔에서 트랙 이름을
  육안 확인**한다(`테스트 및 출시 › 비공개 테스트`, "내부 테스트"가 아니다).
- **`reset_android_caches`가 매 빌드 필수다**(`build_aab`가 자동 실행) — 실측 둘이 근거:
  debug가 소스 위치에 심는 `GeneratedPluginRegistrant.java`가 `integration_test`(dev
  dependency)를 참조해 release javac가 실패하고, `sqflite_common_ffi`가 스테이징한
  `libsqlite3.so`가 release APK에 섞여 들어간다(실측 70.4MB → 65.3MB로 축소 확인).
- **서비스 계정 JSON은 `~/.google_play/planroutine.json` 하나로 일원화**한다 — 같은
  디렉터리의 `service_account.json`은 **바로팀이 이미 쓰는 자리**라, 그 파일명을 쓰면
  엉뚱한 앱 자격증명으로 배포한다(실측 사고, 2026-08-02). `assert_play_key`가
  `client_email`에 `planroutine`이 있는지까지 확인해 막는다.
- **게이트는 iOS와 동일**(`flutter analyze` + `flutter test`) **+ release AAB 스모크** —
  bundletool로 AAB를 에뮬레이터에 설치해 버스 카드가 실제 도착 정보를 그리는지 확인한다
  (TAGO 키가 release 빌드에 실제로 주입됐다는 유일한 증거).
- **첫 업로드는 레인으로 할 수 없다** — Play API는 패키지가 앱에 바인딩되기 전엔
  `insert_edit`에서 404를 던진다. 이 앱은 콘솔 수동 업로드로 이미 지났지만, **다음 앱을
  낼 때 같은 벽을 다시 만난다.**
- **되돌릴 수 없는 것**: 패키지명 확정(`bootstrap`의 첫 업로드) · keystore(업로드 키 —
  분실·교체 시 같은 앱으로 업데이트를 낼 방법이 없다, 리포 밖 보관 필수) · 최종 심사
  제출(`beta`는 `release_status: "completed"`라 업로드 즉시 Play 심사로 들어간다).

### 배포 플로우 정책 (메모리에 기록됨)
`flutter analyze` + `flutter test` 통과 시 사용자 승인 없이 바로 `./ios/bin/fastlane.sh beta` 실행 후 push까지 진행. 배포 실패 시에만 멈춰서 보고.

**예외 — Android 첫 `beta`는 콘솔 육안 확인을 끼운다.** 자동으로 push까지 진행하지 않고,
Play 콘솔에서 트랙이 실제로 `비공개 테스트`(`Alpha`)에 올라갔는지 확인한 뒤에만 완료로
보고한다 — 트랙을 `internal`로 착각하면 14일 비공개 테스트 요건이 하루도 안 세는,
되돌릴 수 없는 손실이기 때문이다.

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
- **iOS 플러그인은 SPM + CocoaPods 혼합이다**(Flutter 3.44의 기본값, 2026-08-03 전환). `ios/Podfile.lock`의 pod이 **52 → 10개**로 줄고 SPM을 지원하지 않는 플러그인만 pod으로 남는다(`charset_converter`·`device_calendar`·`flutter_local_notifications` 등). `project.pbxproj`에 `FlutterGeneratedPluginSwiftPackage` 로컬 패키지 참조, `Runner.xcscheme`에 `xcode_backend.sh prepare` PreAction이 붙는다. **`Package.resolved` 두 개**(`Runner.xcworkspace`·`Runner.xcodeproj/project.xcworkspace`)가 SPM의 lockfile이라 Podfile.lock과 같은 이유로 **커밋 대상**이다. CocoaPods 전용으로 되돌리려면 `flutter config --no-enable-swift-package-manager` 후 재빌드.
  - 검증됨: analyze · 유닛/위젯 · E2E 19 · **두 스토어 `beta` 레인**
    (Android `versionCode 143 / alpha` 2026-08-03 · iOS `TestFlight v144 VALID` 2026-08-04).
    TAGO 키는 IPA와 AAB 양쪽 스냅샷에서 문자열로 확인했다(양성 대조 포함).
    ⚠️ iOS는 **CocoaPods 구성**으로 통과했다 — SPM 빌드(`v143`)는 거부됐다(아래 참고).
  - ⚠️ **SPM은 되돌렸다**(2026-08-04). SPM으로 만든 첫 IPA(`v143`)가 Apple 처리에서
    거부됐다 — `90683 Missing purpose string in Info.plist` (`NSCameraUsageDescription`).
    기제는 링크 구조 변경이다: `file_picker`의 카메라 참조 코드가 CocoaPods에서는
    별개 프레임워크 번들에 있었는데 SPM에서는 **`Runner.app` 본체에 정적 링크**되고,
    Apple의 purpose string 검사는 **번들 단위**다(오류 문구도 "the Info.plist file for
    the **Runner.app** bundle"). 같은 `Info.plist`로 CocoaPods 빌드인 `v142`는 통과했다.
    - **SPM을 다시 도입할 때는** `NSCameraUsageDescription`을 넣고, 경고로만 나온
      `NSLocationWhenInUseUsageDescription`처럼 **플러그인이 자기 번들에 갖고 있던
      purpose string 전수를 옮겨야 한다** — 이번 오류가 마지막이라는 보장이 없다.
      릴리스 중간에 섞지 말 것.
    - 이 실패는 **로컬에서 잡을 수 없다.** `flutter build ipa`는 성공하고 IPA에 키까지
      들어 있었다 — purpose string 검사는 Apple 서버에서만 돈다.
- **SDK를 올린 뒤에는 `flutter clean`이 필요하다.** 엔진이 기대하는 셰이더 포맷이 바뀌면 캐시에 남은 옛 번들이 `Asset 'shaders/ink_sparkle.frag' … Expected 2, got 1`로 터진다(실측 — 바로팀 테스트 6건이 이것으로 실패했고 clean 후 278/278 통과). 같은 SDK를 두 앱이 공유하므로 **한쪽을 올리면 다른 쪽도 clean**해야 한다.
- 통합 테스트(simulator 빌드) 직후 바로 빌드하면 **simulator slice가 framework에 남아** altool 업로드 거부(91169). → **beta 레인**의 `reset_ios_caches`가 자동 차단(release는 빌드 없이 promote만 하므로 무관).
- **수동 `flutter build ipa`로는 배포하지 않는다.** 캐시만 비우고(`flutter clean && rm -rf ios/Pods ios/Podfile.lock ios/build`) **다시 `beta` 레인으로** 빌드한다. 수동 명령에는 `--dart-define-from-file`이 없어 **TAGO 키가 빠진 IPA**가 나오는데, release 레인의 가드 넷(A 버전·B VALID·D 심사단계·E 릴리즈노트) 어디도 키를 보지 않아 **버스 기능이 조용히 죽은 빌드가 심사에 오른다**. 화면에는 `버스 정보를 불러올 수 없어요`만 떠서 사후 진단도 어렵다(설계상 사용자에게 키 이야기를 하지 않는다).

## 샘플 데이터
- `data/sample/2025_생산문서등록대장.csv` — **합성** 생산문서등록대장 20건 (가상 학교·가명, 실제 PII 없음)
  - 핵심 컬럼: 등록일자, 제목, 과제명, 과제카드명, 결재유형
  - 업무 분류·공개구분(공개/부분공개/비공개) 다양성을 갖춰 파서·필터 테스트용 커버리지 유지
  - ⚠️ 실제 학교 데이터 절대 커밋 금지 — 이 파일은 포맷 예시일 뿐(과거 실데이터는 히스토리에서 제거됨, 2026-07)

## Claude Code 훅 (`.claude/`)

산문 규칙은 컨텍스트가 길어지면 강제력이 사라진다. 절대 규칙 셋을 훅으로 내렸다
(`.claude/settings.json` + `.claude/hooks/*.sh`).

| 훅 | 시점 | 하는 일 |
|---|---|---|
| `guard-bash.sh` | PreToolUse(Bash) | 위험 명령 차단 + `android beta` 전제조건 검사 |
| `protect-tests.sh` | PreToolUse(Edit\|Write) | 테스트 **선언 개수 감소** 차단 |
| `analyze-edited.sh` | PostToolUse(Edit\|Write) | 편집한 `.dart` 하나만 `dart analyze` |

**종료 코드가 곧 정책이다**: `0` 통과(stdout은 디버그 로그로만 간다 — 아무도 못 본다) /
`2` 차단(stderr **전문**이 Claude에게) / **그 밖은 비차단 경고**(실행은 계속되고
transcript에 stderr **첫 줄만** 뜬다 — 그래서 경고 문구는 한 줄로 쓴다).

### deny는 "위험한가"가 아니라 "정당한 사용이 0인가"로 정한다

- **`bootstrap`·force push·커밋 훅 건너뛰기·`test|integration_test|lib`를 지우는 `rm`**
  → 무조건 차단. 정당한 사용이 없거나(패키지명은 확정됐다) 사용자가 직접 하면 된다.
- **`rm -rf build ios/Pods`는 막지 않는다** — 이 리포의 정상 절차(수동 캐시 리셋)다.
- **`android beta`는 막지 않는다.** 정당한 사용이 있는 명령을 매번 막으면 마찰이 쌓이고,
  **마찰은 훅을 지운다**(그러면 `bootstrap` 차단까지 함께 사라진다). 대신 전제조건을 본다.

### `beta` 게이트가 보는 것과 보지 않는 것

`flutter analyze` + **배포 가드 테스트만**(`test/deploy` + `data_source_credit_test`).
실측 warm 10.2초. 전체 926건은 배포 리듬을 해쳐 뺐다 — **기능 회귀는 이 게이트가 잡지
않는다**(의도된 한계). 릴리즈 노트가 없으면 **경고만** 한다: 레인이 의도적으로 막지 않는
지점이라(M1 껍데기 업로드를 문구 작성에 걸리게 하지 않으려고) 훅이 그 설계를 뒤집지 않는다.

- **fail-closed다.** `flutter`를 못 찾으면 통과시키지 않는다. 조용히 통과하면 "게이트가
  걸려 있다고 믿는데 안 걸린" 상태가 되고, 그 업로드는 `release_status: "completed"`라
  **즉시 Play 심사**로 가며 versionCode는 되돌릴 수 없다.
- ⚠️ **훅은 로그인 셸을 거치지 않아 `/opt/homebrew/bin`이 PATH에 없다**(실측: bare PATH에서
  `flutter`·`dart` 모두 not found, `jq`만 `/usr/bin`에 있다). 스크립트가 PATH를 주입한다.
- iOS `beta`는 게이트하지 않는다(요청 범위). 넓히려면 `guard-bash.sh` 아래쪽 `case`에
  한 줄을 더한다.

### 명령 문자열에서 데이터를 걷어낸다 (`strip_data`)

**이 가드가 처음 오차단한 것은 자기 자신을 커밋하는 명령이었다**(2026-08-13). 커밋 메시지가
`--no-verify`를 **설명**하기만 해도 플래그로 읽혔다. `strip_data`가 힙독 본문과 인용
문자열을 걷어낸 뒤 검사한다 — 플래그는 인용 밖에 있고, 인용·힙독 안은 사람이 읽을 글이다.

- 같은 이유로 위험 패턴은 **명령 세그먼트 단위**로 본다. 통으로 grep하면
  `rm -f x && git push`의 `-f`가 force push로, `rm -f x && flutter test test/foo`의 `test/`가
  테스트 삭제로 읽힌다(둘 다 실제로 밟았다).
- 남은 구멍 둘: 힙독은 **첫 `<<` 뒤를 끝까지** 자르므로 `cmd <<EOF … EOF && git push --force`를
  놓치고, 인용 제거는 줄 단위라 **여러 줄에 걸친 `-m "…"`** 안의 플래그는 아직 걸린다.

### 테스트 보존은 "Write 금지"가 아니라 "감소 금지"다

전면 재작성은 정당한 사용이 있다(큰 리팩터 뒤 구조 변경). 막아야 할 것은 재작성이 아니라
**감소**라, `test(`·`testWidgets(`·`group(` 선언 수를 세어 비교한다(Write는 디스크 대 새 내용,
Edit는 `old_string` 대 `new_string`). 새 파일은 검사 대상이 아니다.

### `dart format` 훅은 두지 않는다

실측으로 **273개 중 177개가 바뀐다** — 이 리포는 Dart 3.7+ tall-style로 포맷된 적이 없다.
편집 파일만 포맷해도 실제 변경과 포맷 잡음이 한 커밋에 섞인다. 포맷을 도입하려면 훅이 아니라
**전용 커밋 1회**로 바닥을 맞춘 뒤에.

### 가드의 가드

`bash .claude/hooks/test_hooks.sh` — 26건. 훅은 `flutter test`가 스캔하지 않는 자리에 있어
스스로 지켜야 한다. **자산은 오차단 케이스 5건**이다(위에 적은 실제로 밟은 것들). 차단 규칙을
손볼 때 그것들이 먼저 깨지는지 본다.

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
- **`pumpAndSettle`은 이미지 디코드를 기다려 주지 않는다.** "settle"은 "예약된 프레임이
  없다"는 뜻이고, 비동기 이미지 디코드는 **끝날 때까지 프레임을 예약하지 않는다** — 그래서
  디코드 중에도 곧바로 반환한다. 에셋 이미지를 캡처·검증할 때는 `tester.runAsync` 안에서
  `precacheImage`로 디코드를 끝내고 프레임은 존 밖에서 돌린다(`test/tools/seal_preview.dart`).
  위젯 테스트와 통합 테스트 **양쪽 다** 걸린다 — fake-async 문제가 아니다.
  (참고: 실제 디코드는 시뮬 디버그 빌드에서도 첫 회 6.8ms·이후 1.3ms로 한 프레임 안이라
  **앱 동작에는 영향이 없다**. 프리캐시는 테스트 캡처용이지 제품 수정이 아니다.)
- 날짜 문자열 포맷은 `date_utils.formatDate(DateTime) → 'YYYY-MM-DD'` 공용 함수 사용
- 확인 다이얼로그는 `ConfirmDialog.show()` 공통 위젯 사용 (신규 AlertDialog 직접 만들지 않기)
- 설정 섹션 추가 시 `SettingsSection` wrapper + `widgets/{name}_list_tile.dart`에 위젯 분리
- **`ListTile`(`ExpansionTile` 포함) 위에 색칠된 컨테이너를 끼우지 않는다.** ListTile은 배경과
  잉크를 **가장 가까운 `Material`** 에 그리므로, 사이에 배경색 있는 `Container`/`DecoratedBox`가
  있으면 **탭해도 잉크 스플래시가 보이지 않는다** — 에듀파인 가이드 카드가 그 상태였고 아무도
  신고하지 않았다. 배경·테두리는 `Material(color:, shape: RoundedRectangleBorder(...))`가
  직접 지게 한다(중첩 깊이가 같아 자식 블록은 손대지 않아도 된다).
  Flutter 3.44부터 debug assert가 이 조합을 잡는다(`ListTile background color or ink splashes
  may be invisible`) — 릴리스에서는 사라지는 assert라, **업그레이드 때 테스트를 돌리는 것이
  이 결함을 만나는 유일한 창**이었다.
- **플랫폼 분기는 `dart:io`의 `Platform.isAndroid`를 쓴다.** `defaultTargetPlatform`은
  `flutter test`에서 **항상 `android`로 강제된다**(`_platform_io.dart`의 assert 블록) —
  그걸로 분기하면 macOS 호스트에서 도는 위젯 테스트 전체에 Android 전용 UI가 나타난다.
  `Platform.isAndroid`는 위젯 테스트로 직접 못 밟으므로, 새 플랫폼 분기 UI는 기본값이
  `Platform.isAndroid`인 주입점(예: `showXxx: bool?`)을 둬서 테스트 가능하게 만든다.
- **adaptive 아이콘의 `markScale 0.85`(`test/tools/gen_app_icon.dart`)와
  `adaptive_icon_foreground_inset: 0`(`pubspec.yaml`)은 짝이다.** `flutter_launcher_icons`가
  기본으로 전경에 16% inset을 더 넣는데, `LogoHybridPainter`가 이미 캔버스의 65.2%만
  실제로 칠하는 것까지 계산해 안전 영역(원형 마스크 기준 66%)을 맞춘 값이 `markScale`이다
  — 하나만 바꾸면 로고 크기가 안전 영역보다 작거나(이중 축소, 실측: markScale 0.6 +
  inset 16% → 안전 영역의 44%만 채움) 마스크 가장자리에 닿는 쪽으로 어긋난다.
