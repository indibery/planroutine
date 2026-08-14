# 프로젝트 구조 (상세)

CLAUDE.md의 `## 프로젝트 구조`가 요약만 두고 이 파일을 가리킨다. **가장 빨리 낡는 문서**라
본문에서 뺐다 — 파일 목록 자체는 Glob으로 언제든 다시 만들 수 있고, 여기 값은 파일 이름이
아니라 **한 줄 설명**에 있다.

⚠️ 여기 적힌 설명이 코드와 어긋나면 **코드가 맞다.** 이 파일을 지키는 가드는 없다
(CLAUDE.md의 `1003 유닛/위젯` 숫자와 같은 처지다). 실제로 옮기면서 두 군데가 낡아 있었다 —
E2E가 `20 시나리오`로 적혀 있었지만 `app_test.dart`의 `testWidgets`는 **19**개이고,
`screenshot_test.dart`는 트리에 아예 없었다(2026-08-13 실측).

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
│   │   │       ├── ai_photo_flow.dart          # 프롬프트 복사 / 붙여넣기→바로 검토 대기 등록 (히어로 전용)
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
│   │   │       │   ├── theme_mode_tile.dart        # 시스템/밝게/어둡게 세그먼트
│   │   │       │   ├── export_list_tile.dart
│   │   │       │   ├── calendar_integration_section.dart  # 옛 google_account_list_tile
│   │   │       │   ├── notification_settings_tiles.dart
│   │   │       │   ├── stamp_settings_tiles.dart   # 도장 모양 한 줄 + 흐리게
│   │   │       │   ├── stamp_style_sheet.dart      # 도장 모양 2열 그리드 시트
│   │   │       │   ├── bus_settings_tiles.dart     # 버스 설정 본문 (화면이 감싼다)
│   │   │       │   ├── bus_summary_list_tile.dart  # 설정 탭 버스 요약 한 줄
│   │   │       │   ├── trash_list_tile.dart
│   │   │       │   ├── reset_list_tile.dart
│   │   │       │   ├── privacy_policy_list_tile.dart   # 법적 표시 — 탭 가능한 별 섹션
│   │   │       │   ├── app_info_list_tile.dart
│   │   │       │   └── data_source_list_tile.dart      # 출처 표시 (라이선스 의무)
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
├── data/sample/                        # 테스트용 CSV (합성 — 실데이터 금지)
├── docs/
│   ├── notes/project-structure.md      # 이 파일
│   ├── release_notes/                  # <버전>.ko.txt (fastlane이 읽는다)
│   ├── app_store_description.md · play_store_description.md   # 스토어 문안 (단일 원본)
│   └── superpowers/specs/              # 설계 기록 (특정 시점 스냅샷)
├── test/
│   ├── deploy/                         # 문서↔코드 가드 (레인·Gson·스토어 등록정보)
│   ├── features/                       # 단위/위젯 테스트
│   ├── helpers/                        # test_database.dart(FFI in-memory) · data_source_agencies.dart
│   └── tools/                          # gen_app_icon · seal_preview 등 (파일명에 _test 없어 자동 스캔 제외)
└── integration_test/
    ├── app_test.dart                   # UX E2E 19 시나리오
    └── screenshot_test.dart            # 스토어 스크린샷 촬영
```
