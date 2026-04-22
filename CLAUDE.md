# PlanRoutine (공직플랜)

## 프로젝트 개요
**공직플랜** — 계획(Plan)과 반복(Routine). 초등 교사를 위한 업무 일정 관리 앱.
매년 반복되는 교사 업무 사이클을 작년 데이터 기반으로 올해 일정으로 빠르게 세팅.
작년 CSV를 가져와 일정 탭에서 검토·확정하는 흐름이 핵심.

## 핵심 기능
1. **작년 일정 가져오기** — 설정 탭 1줄 진입 → `/import` 풀스크린 플로우에서 CSV 업로드. 플랜루틴 자체 포맷 CSV는 재임포트 시 확정 상태로 즉시 복원.
2. **검토 후 확정** — 일정 탭에서 슬라이드로 확정(→) / 삭제(←). 진행도 행 우측의 `전체 확정` pill로 일괄 확정. 확정 시 캘린더 이벤트 자동 생성.
3. **자체 캘린더** — 앱 내 이벤트 CRUD, 양방향 스와이프 (→ Google 저장 / ← 완료 토글).
4. **휴지통** — 일정/이벤트 soft-delete, 30일 후 자동 영구 삭제.
5. **내보내기** — 확정된 일정을 UTF-8 BOM CSV로 공유시트에 전달.
6. **Google 캘린더 연동** — 단방향(앱 → Google) 이벤트 저장, `google_event_id`로 중복 방지.
7. **로컬 알림** — 월초 · 1주 전 · 1일 전 08:00 알림 (timeSensitive).

## 타깃 사용자
- 매년 비슷한 업무 사이클을 가진 초등 교사

## 기술 스택

| 레이어 | 기술 | 비고 |
|--------|------|------|
| 앱 | Flutter 3.x (Dart) | iOS 배포 중. Android는 코드는 있으나 미검증 |
| 상태 관리 | Riverpod | 다른 라이브러리 사용 금지 |
| 라우팅 | GoRouter | ShellRoute 3탭 (캘린더/일정/설정) + push(/trash, /import) |
| 로컬 DB | sqflite | 스키마 v4 (3 테이블, soft-delete + completed + google_event_id) |
| 모델 | Freezed + json_serializable | 불변 객체 |
| CSV 파싱 | csv + charset_converter | EUC-KR/UTF-8 BOM 자동 감지 |
| 파일 선택 | file_picker | |
| 공유 | share_plus, path_provider | 임시 디렉토리 + 공유시트 |
| 앱 정보 | package_info_plus | 설정 탭 버전 표시 |
| 영구 설정 | shared_preferences | 알림 설정, 힌트 바 dismiss |
| 구글 | google_sign_in 6.x + googleapis 13.x + http | 단방향 Calendar API |
| 알림 | flutter_local_notifications + timezone | 로컬 TZ 예약, timeSensitive |
| 날짜 | intl | 한국어 로케일 |
| 테스트 | flutter_test, integration_test, sqflite_common_ffi | 109 유닛 + 11 통합 |

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
│   │   │       └── trash_strings.dart
│   │   ├── theme/                      # app_theme, app_gradients, app_text_styles
│   │   ├── router/                     # GoRouter (3탭 + /trash, /import 푸시)
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
│   │   └── onboarding/                 # 최초 진입 플로우
│   └── shared/
│       └── widgets/
│           ├── main_shell.dart         # 하단 탭 Shell
│           ├── floating_tab_bar.dart   # 이름은 legacy, 현재 화면 폭 불투명 탭바
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
- 설정 화면에서는 마스터 스위치 하나만 노출 + 현재 설정 요약(`08:00 · 월초·1주 전·1일 전`) subtitle. 월초/1주 전/1일 전/알림 시각/테스트/예약된 알림 보기는 `고급` ExpansionTile 안에 접힘.

### Google Calendar 연동
- `google_sign_in`으로 `authHeaders` 획득 → 커스텀 `http.BaseClient`로 `googleapis` 호출.
- 단방향(생성만) — 수정/삭제 동기화 없음 (개인정보 최소 노출).
- GCP OAuth client는 "테스트" 모드, 테스트 사용자 수동 등록 필요. App Store 출시 시 verification 필요.

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
- `shared/widgets/floating_tab_bar.dart`(이름은 과거 플로팅 디자인의 잔재) — 실제로는 화면 폭을 꽉 채운 불투명 navyMid 바 + 상단 1px 골드 라인. `extendBody: false`라 리스트가 탭바 뒤로 비치지 않고 FAB도 Scaffold가 자동으로 바 위에 올려준다.

## 배포

### 명령
```
./ios/bin/fastlane.sh beta     # TestFlight
./ios/bin/fastlane.sh release  # App Store
```
- Wrapper가 Homebrew Ruby(`/opt/homebrew/opt/ruby/bin`)를 PATH 앞에 주입해 `bundle exec fastlane`을 돌린다. 사용자 shell 설정은 건드리지 않는다.
- `ios/Gemfile`에 fastlane + cocoapods 고정. 최초 실행 시 wrapper가 자동으로 `bundle install`.
- build_number는 Fastfile이 `latest_testflight_build_number + 1`로 자동 계산.

### 배포 플로우 정책 (메모리에 기록됨)
`flutter analyze` + `flutter test` 통과 시 사용자 승인 없이 바로 `./ios/bin/fastlane.sh beta` 실행 후 push까지 진행. 배포 실패 시에만 멈춰서 보고.

### 앱 아이콘 재생성
```
flutter test test/tools/gen_app_icon.dart   # 1024x1024 원본 갱신
dart run flutter_launcher_icons              # 각 iOS 사이즈 재생성
```
- `test/tools/gen_app_icon.dart`는 파일명에 `_test`가 없어 `flutter test` 자동 스캔에서 제외됨. 명시 지정 시에만 실행.

### App Store Connect API key
- 경로: `~/.appstoreconnect/private_keys/AuthKey_D8W86CLKHY.p8`
- Bundle ID: `com.planroutine.app`
- 수동 폴백: `xcrun altool --upload-app --type ios --file build/ios/ipa/공직플랜.ipa --apiKey D8W86CLKHY --apiIssuer 69a6de72-97eb-47e3-e053-5b8c7c11a4d1`

### 알려진 빌드 이슈
- 통합 테스트(simulator 빌드) 직후 바로 release 빌드하면 **simulator slice가 framework에 남아** altool 업로드 거부(91169).
  → `flutter clean && rm -rf ios/Pods ios/Podfile.lock ios/build && flutter pub get && (cd ios && pod install) && flutter build ipa`

## 샘플 데이터
- `data/sample/2025_생산문서등록대장.csv` — 실제 2025년 생산문서 65건
  - 핵심 컬럼: 등록일자, 제목, 과제명, 과제카드명, 결재유형
  - 업무 분류: 일과운영관리(28), 교육과정계획(10), 조직통계(7), 학생학적(4)

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
- 날짜 문자열 포맷은 `date_utils.formatDate(DateTime) → 'YYYY-MM-DD'` 공용 함수 사용
- 확인 다이얼로그는 `ConfirmDialog.show()` 공통 위젯 사용 (신규 AlertDialog 직접 만들지 않기)
- 설정 섹션 추가 시 `SettingsSection` wrapper + `widgets/{name}_list_tile.dart`에 위젯 분리
