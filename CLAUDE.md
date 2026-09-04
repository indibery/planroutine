# PlanRoutine (공직플랜)

## 프로젝트 개요
**공직플랜** — 계획(Plan)과 반복(Routine). 초등 교사를 위한 업무 일정 관리 앱.
매년 반복되는 교사 업무 사이클을 작년 데이터 기반으로 올해 일정으로 빠르게 세팅.
**입력 탭**에서 넣고(월간 일정표 사진 → AI 변환 / 작년 CSV) 그 아래 검토 목록에서
확정하는 흐름이 핵심. 항목은 **업무**(내가 처리할 일)와 **행사**(학교에서 열리는 일)로 나뉜다.

## 핵심 기능
1. **입력 탭(주 경로: 사진 AI)** — 히어로에서 `① 프롬프트 복사 → AI 앱 다녀오기 → ② 붙여넣기` 왕복으로 행사를 등록. 앱은 네트워크를 쓰지 않고 클립보드만 오간다.
2. **작년 업무 가져오기(보조)** — 입력 탭 히어로 아래 테두리 카드 한 줄 → `/import` 풀스크린에서 CSV 업로드. **진입점은 이 한 곳뿐**(설정 탭에서 제거). 플랜루틴 자체 포맷 CSV는 재임포트 시 확정 상태로 즉시 복원.
3. **업무 / 행사 구분** — `EntryKind`(task/event). CSV 경로는 **업무 고정**, 사진 AI 경로는 히어로 세그먼트로 **사용자가 고른다**(기본 행사). 오늘 탭에는 업무만, 캘린더에는 둘 다.
4. **검토 후 확정** — 입력 탭은 **검토 대기만** 보여준다(필터 없음). 슬라이드로 확정(→) / 삭제(←). 하단 `일괄 업무 확정 N건` / `일괄 행사 확정 N건` pill로 종류별 일괄 확정(해당 종류 0건이면 숨김). 확정 시 캘린더 이벤트 자동 생성(종류 승계)되고 이 목록에서 빠진다 — **행은 남는다**(내보내기·`작년` 배지·중복 체크가 본다). 대기가 없으면 문구 한 줄.
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
| 테스트 | flutter_test, integration_test, sqflite_common_ffi | **1070** 유닛/위젯 + 19 E2E (실측 2026-09-03. 부모 커밋 `b6fd263`을 워크트리로 재보니 **1078**이라 순변화는 −8이다 — 필터 가드가 사라진 만큼 새 가드가 들어왔다. ⚠️ 이 숫자를 지키는 가드가 없어 세 번 낡아 있었고, 이번에는 부모 커밋을 직접 재서 적었다) |

## 프로젝트 구조

Feature-first. **파일별 한 줄 설명이 붙은 상세 트리는 `docs/notes/project-structure.md`** —
가장 빨리 낡는 문서라 본문에서 뺐다(옮기면서 실제로 두 군데가 낡아 있었다).

```
lib/
├── main.dart · app.dart   # 시작 시 purge·알림 sync·onboarding / GoRouter + 공유파일 채널
├── core/                  # constants(strings·colors·sizes) · theme · router · database · utils
├── features/              # 아래 표
└── shared/widgets/        # main_shell · floating_tab_bar · gold_fab · brand_logo ·
                           #   gold_gradient_button · section_header · confirm_dialog
```

| feature | 무엇 |
|---|---|
| `import/` | 넣기 — 사진 AI(`ai_photo_flow`) + 작년 CSV(`/import`) |
| `schedule/` | 입력 탭 — 검토 대기 목록·확정, `EntryKind` (필터 없음) |
| `calendar/` | 자체 캘린더 — 월 그리드, 편집 시트 |
| `today/` | 오늘 탭 — 업무만, 완료 도장·결산 링 |
| `bus/` | 출퇴근 버스 도착 카드 — TAGO/GBIS 소스 라우팅 |
| `notifications/` | 로컬 알림 — `computeNotifications`(순수) + syncer |
| `settings/` | 설정 탭 — 섹션별 위젯 분리 |
| `google/` · `trash/` · `onboarding/` | Google Calendar 단방향 · 휴지통 · 최초 진입 |

각 feature는 `data/` · `domain/` · `presentation/`으로 나뉘고 **빈 레이어는 만들지 않는다**
(`trash/`는 `presentation/`만 있다).

- `ios/` — `Runner/`(Info.plist·AppDelegate·SceneDelegate) · `fastlane/` · `bin/fastlane.sh`
- `android/` — `app/`(build.gradle.kts·proguard-rules.pro·`res/raw/keep.xml`) · `fastlane/` · `bin/fastlane.sh`
- `assets/` — `icon/` · `images/` · `fonts/`(Pretendard) · `data/sample/`(합성 CSV, 실데이터 금지)
- `docs/` — `notes/` · `release_notes/` · 스토어 문안 · `superpowers/specs/`
- `test/` — `deploy/`(문서↔코드 가드) · `features/` · `helpers/` · `tools/`(자동 스캔 제외)
- `integration_test/` — `app_test.dart`(UX E2E 19) · `screenshot_test.dart`(스토어 촬영)

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

#### 공휴일은 이름을 가진 **수정 불가 행**으로 목록에 뜬다 (2026-08-18)

빨간 날은 보이는데 **무슨 휴일인지 알 수 없었다**(사용자 신고). `korean_holidays.dart`가
날짜만 담고 이름은 **주석에만** 있었다 — 주석을 데이터로 올렸다.

- **연휴는 첫날에만** 이름과 범위(`9.24~9.26`)를 적는다. 사흘에 세 번 같은 이름을 적으면
  목록이 시끄럽고, 한 줄이 "사흘 쉰다"를 더 잘 말한다(사용자 결정).
- **런 판정 규칙: 연속한 날이 같은 이름을 공유하면 한 런**(`koreanHolidayRunAt`). 그래서
  **자료 작성 규칙이 생겼다** — 추석 3일에 같은 이름(`추석 연휴`)을 넣어야 한 런이 된다.
  붙어 있는 대체공휴일을 연휴에 합치려면 그것도 같은 이름을 준다(2027 설날 `2/6~9`).
  둘째 날부터는 `null`이 나오므로 **호출부에 조건문이 없다.**
- ⚠️ **일정이 없는 공휴일은 키가 없어 섹션 자체가 안 생긴다.** `MonthEventList`가
  `groupedEntries`(날짜 → 이벤트)로 섹션을 그리기 때문 — 일정 없는 개천절은 그릴 자리가
  없었다. `mergeHolidayKeys`(순수 함수)가 **런 시작일을 빈 키로 합쳐** 자리를 만든다.
  둘째 날은 합치지 않는다(빈 섹션만 늘고 얻는 게 없다).
- **`CalendarEvent`로 만들지 않는다.** 공휴일은 이벤트가 아니라 배경 사실이고 id도 DB 행도
  없다. 타입을 빌리면 스와이프·편집·완료 경로가 전부 이 행을 대상으로 여기게 되고, 그걸
  막는 분기를 그 경로마다 심어야 한다. `Dismissible`로 감싸지 않고 탭 콜백도 없다.
- 모양은 **테두리 + 붉은 글씨**다(채움이 아니다) — 누를 수 없는 것은 조용해야 하고,
  사용자 일정(흰 카드 + 채움 배지)과 형태로 갈린다.
  - **배경 채움은 다크에만 있다**(`calendarHolidayRowFill`: 다크 붉은 기 7% / 라이트
    투명. 실기기 신고 2026-08-18). **알파 하나로 두 테마를 맞출 수 없다** — 라이트의
    `inkRed`(#C0392B)가 다크(#E08978)보다 진해서 같은 7%가 흰 배경 위에서는 **분홍 띠**로
    읽힌다. 날짜 선택 대비가 라이트에서만 뭉개졌던 것과 같은 부류다 — **이 계열 결함은
    라이트로 봐야 보인다.**
  - 채움을 빼도 신호는 둘 남는다: 형태(테두리)와 색(붉은 글씨). 가드는
    `holiday_row_test.dart`가 **두 테마를 각각 렌더**해 라이트 알파 0 · 다크 0 초과 ·
    양쪽 테두리와 글씨가 붉은지 본다.
  - ⚠️ **프리뷰(`test/tools/`)에서는 아이콘이 네모(두부)로 나온다.** 테스트 환경이 Material
    아이콘 폰트를 싣지 않아서다(`check`·`star`도 같이 네모임을 확인했다) — 제품 결함이
    아니다. 프리뷰로 디자인을 검토할 때 아이콘 모양은 판단 근거가 되지 못한다.
- ⚠️ **일요일은 공휴일 표에 없다**(색 규칙이 따로 본다). 그래서 `8/15 광복절(토)` ·
  `8/16 일` · `8/17 대체(월)`는 실제로 3연휴인데 **런이 둘로 끊긴다** — 알고 두는 한계다.
- **표 관리 규칙은 비대칭이다** — 과거 연도는 **확정된 사실**이라 지우지 않고, 미래 연도는 **발표된 예정**이라 갱신한다. 지난 해를 지우면 **이름만 사라지지 않는다**: `calendar_day_cell.dart`가 `isKoreanHoliday`로 빨간색을 정하므로 그 해 추석이 검은 평일로 그려지고, `CalendarMonthPager`의 `PageView`에 `itemCount`가 없어 **월 이동에 하한이 없어** 뒤로 넘기면 그 화면에 도달한다.
  - **가드가 막는 것은 "크기 때문에 솎는 것"이 아니다.** 연도당 10줄이라 표가 커져서 정리할 상황은 오지 않는다. 실제 위험은 **표를 다시 쓸 때** 2028년을 넣으면서 2025년을 조용히 빠뜨리는 것이다. 지워서 얻는 것이 0이므로 남기는 이유는 "필요해서"가 아니라 **"버리는 값이 없어서"** 다(2027년 설치자가 2025년을 볼 일은 드문 것이 사실이다). 가드가 막고 실패 메시지가 이유를 설명한다.
  - ⚠️ **표 밖 연도는 조용히 반쪽이 된다.** 고정 공휴일만 나오고 설·추석·대체가 사라지는데 오류도 경고도 없다(실측: 2028-01-26 설날 → 공휴일 아님). 현재 표는 **2025~2027**이라, 사용자가 **2027년 12월에 다음 해를 훑으면** 이미 틀린 화면을 본다. 연도를 추가할 때 테스트의 `probes`에도 한 줄 더한다.
  - **공공데이터포털 특일정보 API를 쓰지 않는다**: 공휴일은 오프라인에서도 보여야 하고, 임시공휴일은 어차피 갑자기 정해져 API도 즉시성을 못 준다(앱을 다시 열어야 안다). 네트워크·처리방침·출처 표시를 새로 지는 대가에 비해 얻는 것이 적다.
- 가드: `korean_holidays_test.dart`(이름·런·범위) · `holiday_month_entries_test.dart`(키 주입) ·
  `holiday_row_test.dart`(**`Dismissible`이 아니다**·연휴 첫날만·빈 상태 문구 대체).
  미리보기는 `test/tools/holiday_row_preview.dart`.

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
- **종류는 CSV 경로만 고정이고, 사진 경로는 사용자가 고른다**: 작년 CSV(생산문서등록대장)
  → **업무 고정** / 사진 AI → **히어로 세그먼트로 선택**(`행사 일정표` / `내 할 일·기한`,
  기본 행사). `PhotoInputHero._source`가 **프롬프트와 등록 종류를 함께** 결정하고
  (`copyAiPhotoPrompt(kind:)`·`pasteAiSchedulesAndRegister(kind:)`), 화면 수명 동안만
  유지한다 — 대부분 학기 초에 일정표를 한 번 넣으므로 기본이 행사이고 쪽지는 그때그때 고른다.
  두 경로 모두 `status=pending`으로 들어와 같은 검토 관문을 지난다.
  - ⚠️ 이 문서는 한동안 `사진 AI 경로 = 행사`라고 **단정**하고 있었다(2026-09-04 사용자 질문에
    걸렸다). 세그먼트가 들어온 변경이 문서를 갱신하지 않았고, 그래서 "사진은 늘 행사"라는
    전제로 판단한 세션이 있었다 — **아래 일괄 확정 pill 두 개의 근거가 정확히 이 사실이다.**
- **승계 지점이 급소**: `CalendarRepository.createFromSchedule`이 `schedules.kind`를 이벤트로 옮긴다. 여기서 끊기면 데이터는 멀쩡한데 오늘 탭에 운동회가 뜨는, 원인이 두 레이어 떨어진 버그가 된다.
- `buildTodayView`가 `e.kind.showsInToday`로 걸러 **오늘 탭은 업무만** 담는다 — 행사에는 완료 개념이 없어 도장·진행 링의 의미가 깨진다.
- 캘린더는 둘 다 보여준다. 월 그리드 점의 종류별 색 구분은 하지 않는다(색 규칙이 이미 골드=오늘·중요, 붉은색=공휴일·일요일, 파랑=토요일·이벤트로 포화). **대신 목록 행에서 구분한다** — 제목 앞 인라인 `KindBadge`(업무=회색 `sub` / 행사=파랑 `info`, 옅은배경 15% + 10px w700).
- **배지는 색이 아니라 세기로 갈린다**(2026-08-14). 라이트에서 업무(`sub`)와 행사(`info`)가 **서로 1.39:1**이라 10px 배지에서 구별이 안 됐다(사용자 신고). 같은 파랑을 **채움/틴트** 두 세기로 나눈다 — **업무가 채움**(내가 처리할 일이고 오늘 탭의 주인공이라 강조를 가져간다), 행사는 틴트.
  - **회색을 쓰지 않는다.** `작년` 배지가 회색 테두리형이라 한 행에 같이 뜬다 — 색 축은 종류, 회색은 출처. 초록은 `확정됨`(`schedule_tile.dart`가 **같은 조립**으로 그린다), 골드는 오늘·중요가 이미 쓴다.
  - 전용 토큰 셋(`kindTaskFill`·`onKindTaskFill`·`kindEvent`)을 새로 뒀다 — `sub`·`info`는 313곳이 써서 못 건드린다. 대비: 라이트 채움 위 흰 글씨 6.32:1, 다크 채움 위 네이비 5.46:1(다크는 흰 글씨가 3.32로 미달이라 네이비를 얹는다).
  - 가드는 `kind_badge_test.dart` — 업무 채움의 알파가 1.0인지, 행사가 0.5 미만인지, 행사 색이 `sub`와 다른지.
- `KindBadge`는 `features/schedule/presentation/widgets/`에 산다(`shared/widgets/`가 아니다). `EntryKind`에 종속인데 `shared/widgets/` 아래 어떤 위젯도 `features/`를 import 하지 않기 때문 — 캘린더가 schedule을 가져다 쓰는 방향은 이미 `calendar_event.dart`에 있다.
- **시트에서 종류를 고를 수 있다**(캘린더 경로만). 손으로 넣은 항목이 전부 업무가 되던 문제를 없앤다. **오늘 탭에서 열면 종류 행을 숨긴다**(`allowKindChange: false`) — 거기서 행사를 만들면 저장 직후 목록에서 사라져 저장 실패로 읽힌다. 행만 숨기고 `_kind` 상태는 살려둬야 오늘 탭에서 편집해도 종류가 보존된다.
- 캘린더에서 종류를 바꿔도 원본 `schedules.kind`는 그대로다(역방향 동기화 없음). `scheduleId`가 있는 이벤트의 종류를 뒤집으면 입력 탭 확정 목록과 캘린더의 배지가 어긋나고 CSV 내보내기는 옛 종류로 나간다. 빈도가 낮아 두고 있는 상태이지 버그가 아니다.

### 입력 탭 구조
- **넣기가 주인공**, 검토는 그 아래. 화면 제목 `입력`(eyebrow `INPUT`), 탭 라벨 `입력`.
- `PhotoInputHero`(import feature) — 왕복 3단 `① 프롬프트 · AI 앱 · ② 붙여넣기`. 가운데 칸은 앱 밖에서 벌어지는 일이라 **누를 수 없다**. 작년 업무 CSV는 아래 **테두리 카드 한 줄**(옅은 글씨면 학기 초에 못 찾는다 — 히어로는 골드 채움이라 위계는 유지된다).
- AI 동작 자체는 `import/presentation/ai_photo_flow.dart`의 `copyAiPhotoPrompt`/`pasteAiSchedulesAndRegister`에 있다 — 호출부는 히어로 하나뿐이다.
- **② 붙여넣기는 확인 시트를 거치지 않는다**(2026-08-14). 예전에는 미리보기 시트에서 `등록`을 누르고 검토 목록에서 또 확정해야 해서, **한 흐름에 같은 것을 묻는 관문이 둘**이었다(사용자 요청). 시트가 하던 말(인식 건수 · 중복 제외 · 형식 오류)은 `ImportStrings.aiRegisterSummary` 한 줄이 진다.
  - **잃은 것은 시트의 취소 버튼이다.** 잘못 붙여넣으면 되돌릴 기회 없이 목록에 들어온다 — 대신 ← 스와이프나 `대기 N건 삭제`로 걷어내고 둘 다 soft-delete라, 값은 휴지통을 거치는 한 걸음뿐이다.
  - `created`가 0이어도 **조용히 지나가지 않는다.** 전부 중복이면 목록이 그대로라, 문구가 없으면 버튼이 눌린 건지 알 수 없다.
  - `insertConfirmedOrPending`이 한 번 더 걸러낸 `skipped`를 중복 건수에 **합쳐서** 말한다. 빼면 우리 키 검사를 통과한 중복이 조용히 사라진다.
- **입력 탭 스낵바는 전부 `showBulkBarSnack`(`lib/shared/bulk_bar_snack.dart`)을 쓴다.**
  `SnackBarBehavior.floating` + 아래 `AppSizes.bulkRegisterBarHeight` 여백. 기본값(`fixed`)이
  앉는 자리가 정확히 하단 일괄 확정 pill이라 4초 동안 확정을 누를 수 없다(사용자 신고
  2026-08-14, **2026-09-03 재신고**).
  - ⚠️ **재신고는 회귀가 아니었다.** 첫 수정이 같은 코드를 `ai_photo_flow.dart`의 **private
    함수로 가둬** 다른 호출부가 쓸 수 없었고, 두 곳이 맨 `SnackBar`를 만든 채 남아 있었다 —
    CSV 등록 완료(신고된 것)와 **← 스와이프 삭제**(그때는 `되돌리기` 액션이 달려 있어 더
    나빴다 — 가려지면 되돌릴 방법 자체가 없었다). 가드도 `photo_input_hero_test.dart`
    하나뿐이라 AI 경로만 봤다.
    **고친 것은 두 번째 호출부가 아니라 "재사용 불가"라는 구조다.**
  - **삭제 스낵바에 실행취소를 달지 않는다**(2026-09-04). 앱의 다른 삭제 경로
    (캘린더 이벤트 삭제 · 일괄 `대기 N건 삭제`)에 없어서 입력 탭의 행 삭제만 예외였고,
    그 비일관이 불편으로 신고됐다. **되돌리는 길은 휴지통 하나로 모은다** — soft-delete라
    값은 남아 있다. 부재 가드는 `schedule_screen_review_test.dart`에 있다.
    - ⚠️ 헬퍼의 `action` 파라미터와 그 가드는 **남겨 뒀다**(지금 넘기는 호출부는 없다).
      액션 있는 스낵바를 입력 탭에 다시 두면 가려지는 순간 그 액션은 못 누르는 버튼이 된다.
    - ⚠️ 앱에 남는 `SnackBarAction`은 **캘린더의 `설정에서 켜기`**(기기 캘린더 권한 거부)
      하나다. 삭제 되돌리기가 아니라 **막힌 길을 여는 안내**라 성격이 다르다 — 위 규칙이
      그것까지 걷어내라는 뜻은 아니다.
  - `showBulkBarSnackWith(messenger, …)` 변종이 있다 — `/import`는 `pop()`으로 사라지면서
    스낵바를 띄우므로 닫기 **전에** messenger를 붙잡아 둬야 한다.
  - 전역 `snackBarTheme`으로 올리지 않는다 — 다른 스낵바 스무 곳의 모양이 함께 바뀐다.
  - 여백은 `AppSizes.bulkRegisterPillHeight`에서 **파생**된다. 숫자를 스낵바 쪽에 따로 박으면
    pill 높이를 바꿀 때 조용히 어긋난다.
  - 가드는 **두 층**이다: `test/shared/bulk_bar_snack_test.dart`(헬퍼 값 + 액션 탭 가능 +
    호출부가 맨 `SnackBar`를 안 만드는지) · `schedule_screen_review_test.dart`(실제 화면에서
    **겹치지 않는지** + 스낵바가 떠 있는 동안 **확정이 눌리는지**).
  - ⚠️ **`find.byType(SnackBar)`의 rect를 재면 안 된다.** 그건 margin을 포함한 레이아웃
    영역이라 floating이어도 화면 맨 아래까지 뻗는다(실측 `LTRB(0,736,390,844)`). 보이는 면은
    그 안의 첫 `Material`(`LTRB(8,736,382,784)`)이다. 바깥 상자를 재면 **정상인 코드를 버그로
    오진한다** — 실제로 이 가드를 쓰다가 한 번 오진했다. 날짜 선택 대비 가드가 "Material이
    칠하는 짝이 아닌 짝"을 쟀던 것과 같은 부류다.
- 하단 종류별 일괄 확정 바 — `일괄 업무 확정 N건` / `일괄 행사 확정 N건`. 건수는 **목록**의 종류별 대기 수이고 0이면 그 pill은 숨는다.
  - **하나로 합치지 않는다**(검토 2026-09-04). 나눠 둔 이유는 화면이 아니라 **확정 뒤가
    다르다**는 것이다 — 업무는 오늘 탭에 뜨고 도장·결산 링의 대상이 되지만 행사는 안 뜬다
    (`kind.showsInToday`). 두 종류는 보통 **다른 날 다른 작업으로** 들어오므로(CSV / 사진),
    한 버튼이면 검토하지 않은 종류까지 함께 캘린더로 넘어간다.
    - **종류 필터 칩을 없앤 뒤(2026-09-03) 이 pill이 종류별로 확정하는 유일한 수단이다** —
      합치면 "한 종류만 확정"이 앱에서 사라진다.
    - 화면이 무거워 보이는 것은 **0건 pill이 숨기 때문에 대개 하나만 뜬다**는 사실이
      가려져서다. 둘이 나란한 상태는 두 경로를 다 쓰고 아직 아무것도 확정하지 않았을
      때뿐이고, 시드 데이터가 늘 그 상태라 개발 중에는 항상 둘로 보인다.
  - 라벨은 `ScheduleStrings.bulkConfirm(kind.label, n)`으로 **조립**한다 — `업무`/`행사`를 여기 다시 박으면 다음 용어 변경 때 배지만 따라가고 pill만 옛 이름으로 남는다(직전 main이 그 상태였다: `kindEvent`는 `학교일정`, pill은 `일괄 일정 등록`).
  - **낱말은 `확정`이다**(2026-08-14). 한동안 이 pill만 `등록`이었는데, 그 pill이 여는 다이얼로그는 제목·본문·버튼이 전부 `확정`이라 **버튼과 그 버튼이 여는 창이 어긋나 있었다.** 게다가 `등록`은 가져오기 스낵바에서 **검토 대기로 넣기**를 가리켜, 한 낱말이 파이프라인의 두 단계(넣기·확정)를 동시에 졌다. 가드는 `schedule_screen_input_test.dart`가 pill 라벨이 `ScheduleStrings.confirm`을 담고 `등록`을 안 담는지 본다.
  - ⚠️ **위젯 키는 `bulkRegister{Task,Event}Key` 그대로다** — 사용자에게 안 보이고, 바꾸면 이 문서와 테스트만 흔든다.
  - "0건이면 숨는다" 가드는 **`ScheduleScreen.bulkRegister{Task,Event}Key`** 로 검사한다. 문자열 `findsNothing`은 라벨을 한 번만 손봐도 아무 데서도 렌더되지 않는 문자열을 찾게 돼 0건 pill을 보고도 통과한다.

#### 필터를 전부 없앴다 — 목록은 항상 검토 대기다 (2026-09-03)

사용자 신고: **"확정됨, 검토대기, 검토대기 보기, 필터 등 너무 다르게 나와서 일관성이
없어."** 한 화면에 목록을 정하는 것이 여섯이었다 — 상태 칩(`검토 대기 N`/`확정됨 N`) ·
종류 칩(`업무`/`행사`) · 카테고리 칩(`전체`/`일과운영`/…) · 접히는 `필터` 토글 ·
진행도 2px 바 · `확정됨 N건 보기` 링크. 전부 없앴다.

- **남은 조작부는 둘뿐이다**: 목록 위 오른쪽 `대기 N건 삭제` pill, 하단 종류별 확정 pill.
- **확정 뷰로 가는 문이 넷이었다** — 상태 칩 · 완료 요약의 `확정됨 N건 보기` ·
  목록 하단의 초록 `확정 N건은 캘린더에 반영됨` 줄 · 진행도 바(건수만 알려주는 장식).
  ⚠️ **셋째를 찾는 데 한 번 실패했다** — 목록 `itemBuilder` 안에 마지막 항목으로 끼워져
  있어 위젯 트리를 위에서 훑으면 안 걸린다. 다음에 "이 뷰로 가는 길"을 세려면
  `ScheduleStatus.confirmed`를 **쓰는 모든 지점**을 grep하는 편이 빠르다.
- **`schedules` 행은 지우지 않는다.** "확정되면 자동 삭제"로 읽히지만 실제로 지우면 세 곳이
  함께 깨진다 — CSV 내보내기(`status='confirmed'`로 조회) · `작년` 배지
  (`calendar_events.schedule_id` → `schedules.source_id` 조인) · 중복 체크
  (`title`+`scheduled_date`, 같은 CSV 재임포트가 매번 사본을 만든다). 사용자 확인 후
  **화면에서만** 빠지게 했고, 그 전제를 가드 셋이 지킨다(아래).
- **삭제는 대기 전체, 확정은 종류별**이다. 비대칭으로 보이지만 화면이 그렇다 — 종류는
  필터가 아니라 **눌린 pill**에서 온다. 범위 조립은 여전히
  `ScheduleRepository._updateAllPending(values, {kind})` 한 곳이고, `확정과 삭제가 같은
  집합을 잡는다` 가드가 건수로 고정한다. (한쪽에만 필터를 더해 어긋난 것이 실제 버그였다:
  `행사 4건 삭제`를 눌러 대기 21건이 전부 휴지통으로 갔고 스낵바는 `4건을 옮겼어요`였다.)
- **목록 행에서도 카테고리 배지를 없앴다**(사용자 결정). 남는 것은 종류 배지·제목·날짜다.
  DB의 `category` 값과 CSV 내보내기의 카테고리 컬럼은 **그대로 둔다** — 화면만 뺐다.
- 대기 0이면 `검토할 일정이 없습니다` 문구 하나. `ScheduleStrings.empty`의 값을
  `등록된 일정이 없습니다`에서 바꿨다 — 목록이 대기 전용이 된 뒤로는 확정 72건이 있어도
  이 목록이 빌 수 있어 옛 문구가 거짓이 된다.
- 같이 죽어 삭제한 것: `schedule_filter_bar.dart` · `filter_summary.dart`
  (`buildFilterSummary`·`buildScopeLabel`·`hasNarrowingFilter`) ·
  `category_label.dart`(`shortenCategory`·`categoryColor`·`confirmAllPillLabel`) ·
  `scheduleStatusFilterProvider`·`scheduleKindFilterProvider`·
  `scheduleCategoryFilterProvider`·`scheduleCountsProvider`·`availableCategoriesProvider` ·
  `getDistinctCategories()` · `getSchedules`/`confirmAllPending`/`deleteAllPending`의
  `category` 인자. 테스트 42건이 함께 사라졌다.
  - ⚠️ **`test/tools/visual_check.dart`도 필터 바를 참조하고 있었다.** `flutter test`가
    자동 스캔하지 않는 파일이라 테스트를 돌려도 안 걸리고 **`flutter analyze`에만** 걸린다.
    `lib/` 위젯을 지울 때는 `test/tools/`까지 grep할 것.
- ⚠️ **`ScheduleTile`의 확정 분기는 이제 도달할 수 없다.** 호출부가 입력 탭 하나뿐이고
  그 목록이 대기 전용이 됐으므로, 초록 `확정` 배지(`schedule_tile.dart:151`)·확정 시
  스와이프 무시(`:51`)·`_statusColor`의 확정 갈래가 모두 죽은 코드다. **지우지 않았다** —
  스와이프 가드는 지워서 얻는 것이 없고, 배지는 목록이 다시 확정을 담게 되면 필요하다.
  읽는 사람이 "확정도 여기 뜨나?"로 오해하지 않게 여기 적어 둔다.
#### 확정 행은 쌓인다 — 자동 정리 대상이 아니고, 개별로 지울 경로도 없다

필터를 없앤 뒤의 구조적 귀결이다. 사용자 확인 후 **그대로 두기로 했다**(2026-09-03).

- `purgeOlderThan`은 `deleted_at IS NOT NULL`만 지운다. 확정 행은 `deleted_at`이 NULL이라
  **30일 정리에 걸리지 않는다** — 영구히 남는다.
- **규모는 문제가 아니다.** 생산문서등록대장이 한 해 100~200건(실측: 시드 149, 사용자
  화면 72)이라 10년이면 2000행 남짓이고, 입력 탭은 `status='pending'`만 조회하므로
  확정분이 늘어도 목록이 느려지지 않는다. 지난 확정 기록이 남는 것은 "작년 데이터로 올해를
  세팅한다"는 이 앱의 전제에 오히려 부합한다.
- ⚠️ **개별 확정 행을 지우는 UI 경로가 사라졌다.** `deleteSchedule(id)`의 호출부는
  입력 탭 목록의 ← 스와이프 **한 곳뿐**이고, 그 목록이 대기 전용이 됐다. 캘린더에서
  이벤트를 지워도 `calendar_events`만 soft-delete되고 `schedules` 행은 남는다.
  남은 것은 **설정 › 전체 데이터 초기화**(전부) 하나다. 예전에는 `확정됨` 뷰로 들어가
  스와이프로 지울 수 있었다 — 그 문을 닫으면서 함께 닫혔다.
- **CSV 내보내기 문구가 이미 틀려 있었다**(제거와 무관한 기존 결함): 쿼리는
  `status='confirmed'` 전부인데 설정 문구는 `올해 등록된 일정을…`이었다. 지금은 대체로
  1년치라 우연히 맞지만 **확정 행이 쌓이는 구조와 만나 매년 더 틀려진다.** 문구를
  `확정된 일정 전체를…`로 고쳤다(사용자 결정: 쿼리는 그대로).
  - 가드는 `test/features/settings/export_scope_claim_test.dart` 3건. 주장이 아니라
    **행동으로** 잡는다 — 2024·2025·2026 확정분을 심고 셋 다 파일에 나오는지 본다
    (`path_provider`는 채널 목으로 임시 디렉터리를 준다). 반대 방향(쿼리만 좁히고 문구를
    안 고치는 것)은 소스에서 연도 필터 표시를 훑어 묶는다.
  - 같은 계열을 이미 밟았다: `deleteAllPending`이 카테고리를 무시하는데 pill은 좁힌
    건수를 말해 `행사 4건 삭제`로 21건이 지워졌다. **범위를 말하는 문구와 범위를 정하는
    쿼리는 양방향으로 묶는다.**

- 가드(건수는 `flutter test`가 세는 값): `schedule_screen_review_test.dart` **14** —
  필터·배지·진행도 부재, 확정 시 목록에서 빠짐, **행 생존 2건**(내보내기 전제·중복 체크
  전제), **삭제 pill 건수 ↔ 실제 삭제 범위** · `schedule_kind_providers_test.dart` **11** —
  목록이 항상 대기, 종류별 확정/삭제 대칭 · `schedule_screen_input_test.dart` **9** —
  두 종류가 한 목록에, 조작부가 pill 하나.
  - ⚠️ **"없음" 단정 일부는 태생부터 반증 불가다.** `필터`·`전체`·`일과운영` 같은
    문자열은 상수와 함께 지워져 lib 어디에도 없으므로, 다른 문안(`필터링`·`분류`)으로
    필터를 되살리면 그 루프는 통과한다. **문안 회귀 감지용**이고 실질 무게는
    `FractionallySizedBox`(진행도 바)·`TextButton`(보기 링크) 부재가 진다.
  - **스낵바는 화면이 센 수가 아니라 DB가 옮긴 수를 말한다**(`deleteAllPending`이 건수를
    반환한다). pill 범위와 쿼리 범위가 갈리면 그 숫자가 어긋나 런타임에도 드러난다 —
    옛 버그는 스낵바가 화면 값을 말해 **사라진 사실조차 알리지 않았다.**

### 용어
- **일정 / 행사 / 업무**를 쓴다. `학교일정`은 쓰지 않는다 — `일정`이 우산말(시트 제목
  `일정 추가/수정`)이자 라벨의 절반이라 겹쳐 읽혔다(사용자 신고, 2026-07-27).
- **`행사`와 에듀파인 카테고리 `학교행사`의 충돌은 없어졌다**(2026-09-03). 화면에서
  카테고리를 전부 뺐기 때문이다 — 필터 칩(`학교행사` 칩)도, 목록 행의 카테고리 배지도 없다.
  **`학교행사`라는 낱말이 UI에 나타나는 자리가 남지 않았다.**
  - 그 전에는 한 행 안에서만 배타적이고 **화면 단위로는 세 곳에서 공존**했다(검토 목록의
    인접 행 · 펼친 필터 패널 · 접힌 필터 요약). 알고 감당하던 지점이었고, 필터 제거가
    그 부채를 함께 갚았다.
  - ⚠️ **DB의 `category` 값은 그대로다.** CSV 내보내기가 그 컬럼을 쓰고, 채우는 경로는
    CSV 경로(`createFromImported`·`createBulkFromImported`·`_importPlanRoutineCsv`)뿐이며
    그 경로는 항상 업무다. 카테고리를 화면에 다시 꺼내려면 축약 규칙
    (`category_label.dart`, 삭제됨 — git 히스토리)부터 되살려야 하고, 그때 위 충돌도 함께
    돌아온다.
- 예외 하나:
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
  - **`작년` 배지가 붙은 항목에만 뜬다**(`showsImportBadge` = `fromImport && reviewedAt == null`,
    2026-08-18). 연도를 밀어야 하는 이유는 "작년 CSV를 가져와 제목에 옛 연도가 남았다"이지
    "제목에 연도가 있다"가 아니다 — 예전에는 후자만 봐서 **사진 AI로 올해 공문을 넣어도
    `2026 → 2027` 칩이 떴다**(사용자 신고).
    - 원인은 커밋 `7643967`(올해로 맞추기 → 한 해 밀기)의 **부수 효과**다. 옛
      `bumpTitleYear(title, currentYear)`의 `if (year < currentYear)`가 **치환 로직과 가시성을
      겸하고** 있었고, 로직만 상대 이동으로 바꾸면서 관문이 함께 사라졌다. 그 상태가
      `올해 연도에도 칩이 보인다` 테스트로 굳어 **부수 효과가 의도처럼** 남아 있었다.
    - 대안이던 "올해보다 이전 연도가 있을 때만"은 **연말에 CSV 항목을 내년으로 미는 경로를
      죽인다.** 배지 조건은 그것을 살리고, 기존 테스트의 의도도 뒤집지 않는다.
    - **순환은 생기지 않는다.** 문서가 걱정한 것은 *배지가 연도를 보는 것*인데, 배지는 여전히
      출처만 본다. 칩이 배지를 보는 **한 방향**이고, 칩을 눌러 저장하면 `reviewed_at`이 기록돼
      배지와 칩이 함께 꺼진다.
    - ⚠️ `fromImport`는 **조회 시점 파생 필드**다(`getEventsByDateRange`의 LEFT JOIN). 두 호출부
      (캘린더·오늘 탭)가 모두 그 쿼리를 쓰므로 편집 시트까지 살아 온다 — **다른 경로로 이벤트를
      넘기면 이 조건이 조용히 false가 된다.**
  - **칩이 꺼지는 이유는 셋, 수명은 제각각이다**: `!_isEditing`(신규 생성 — 편집 경로가 아님, 영구) /
    `!showsImportBadge`(가져온 자료가 아니거나 이미 검토함, 영구·DB) / `_yearShifted`(이 시트를 여는
    동안 이미 한 번 눌렀음, **세션 한정** — 취소하면 사라져 다시 열면 칩이 돌아온다).
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
- **섹션 10개**(캘린더 연동은 flag가 켜졌을 때만이라 실효 9~10): 화면 · 완료 도장 ·
  버스 도착 · 내보내기 · 캘린더 연동(flag) · 알림 · 휴지통 · 데이터 관리 ·
  **개인정보처리방침** · 앱 정보(+출처 표시).
  - 개인정보처리방침은 **탭 가능한 별 섹션**이다(Play User Data 정책상 법적 표시) —
    앱 정보 `Column`은 정보성이고 탭이 없어 거기 섞지 않는다.
  - ⚠️ `SettingsSection(`을 세면 **9개만 나온다** — `CalendarIntegrationSection`은 그
    wrapper 밖에서 자기 자신이 섹션이다. 개수를 셀 때 이것을 빠뜨리기 쉽다.
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
- Initial 뷰에 `EdufineGuideSection` 접힘 안내. **①은 공통, ②는 기기별로 갈린다**(2026-09-04).
  - ① CSV 다운받기 — 번호 4단계 + annotation 스크린샷. 에듀파인은 **업무용 PC 웹**이라
    플랫폼과 무관하고, 그 사실을 힌트 한 줄로 먼저 말한다("PC에서 내려받아 폰으로 옮기는
    순서"). 없으면 "폰에서 에듀파인에 들어가야 하나"로 읽힌다.
  - ② 아이폰 — A. 공유시트(권장) / B. 파일 앱 + `더 보기` 팁 박스.
  - ② 안드로이드 — A. **열기**(권장) / B. 파일 앱. **뼈대를 아이폰과 같게 둔다**
    (A = 앱 밖에서 보내기 / B = 앱에서 고르기) — 그래야 한쪽을 보고 동료에게 다른 쪽을
    설명할 수 있다.
  - ⚠️ **권장 방법이 플랫폼마다 뒤바뀐다.** 매니페스트 필터 폭이 반대라서다 —
    열기(`ACTION_VIEW`)는 `text/plain`·`octet-stream`·와일드카드까지 받고,
    공유(`ACTION_SEND`)는 CSV mime 셋만 받는다.
  - ⚠️ **안드로이드 안내는 공유를 아예 언급하지 않는다**(사용자 결정 2026-09-04).
    언급하면 "카카오톡처럼 일반 텍스트로 보내는 앱에서는 목록에 안 뜬다"를 함께 설명해야
    하고 그 경고가 안내문 절반을 먹는다. **적지 않은 경로는 변명할 것도 없고, 적은
    경로(열기)는 와일드카드까지 받아 항상 동작한다.** 잃는 것은 습관적으로 공유를 눌러
    막힌 사람에게 답을 주지 못하는 것이다.
  - 파일 앱 이름을 특정하지 않는다 — 삼성은 `내 파일`, Pixel은 `파일`이라 `폰의 파일 앱`으로 쓴다.
  - 분기는 `EdufineGuideSection({bool? isAndroid})` 주입점을 통한다(기본값 `Platform.isAndroid`).
    `defaultTargetPlatform`은 `flutter test`에서 **항상 `android`로 강제**돼 못 쓴다.
    가드: `test/features/import/edufine_guide_platform_test.dart` 5건 — 각 기기에서 자기
    안내만 보이는지, 안드로이드에 `공유`가 없는지, ①이 공통인지, 뼈대가 같은지.
    ⚠️ 가드가 한 테스트에서 두 번 pump할 때는 **`key`를 줘야 한다** — 없으면
    `ExpansionTile`의 State가 재사용돼 두 번째 탭이 오히려 **접는다**(실측).

### iOS 공유시트 통합 (외부 앱에서 공직플랜으로 열기)
- 카카오톡/메일/파일 앱에서 CSV 파일 공유 → 공유 목록에 "공직플랜" 노출 → 탭하면 Import 화면으로 자동 이동 + 즉시 파싱. 사용자가 "파일 선택" 탭 불필요.
- `Info.plist`의 `CFBundleDocumentTypes` + `LSSupportsOpeningDocumentsInPlace`로 CSV UTI(`public.comma-separated-values-text` 등) 수신 선언. Share Extension은 불필요.
- `AppDelegate.swift`의 `application(_:open:options:)` 표준 iOS hook + 커스텀 `FlutterMethodChannel("planroutine/shared_file")`로 file URL을 Flutter에 전달. `receive_sharing_intent` 플러그인은 Share Extension + App Groups 기반이라 Open-In flow에서 동작 안 함 — native 직접 구현이 더 간결.
- 타이밍: cold-start로 열린 경우 native `pendingPath` 버퍼, Flutter가 `getPending`으로 꺼냄. running 경우는 `onFileShared` push.
- `GoRouter.redirect`에서 `scheme=file`/`.csv` 접미사 URL을 가로채 `/import`로 전환 → "Page Not Found" 방지.
- `SceneDelegate.swift`에서 scene URL 이벤트를 `AppDelegate.application(_:open:options:)`로 포워딩 (iOS 13+ scene lifecycle 대응).

### Android 공유·열기 (M2, 2026-08-14) — **같은 채널, 다른 URI**

`MainActivity.kt`가 iOS `AppDelegate`와 **같은 계약**을 쓴다(`planroutine/shared_file` ·
`getPending` · `onFileShared`). 한 줄짜리 `FlutterActivity()`였던 파일에 인텐트 수신·
채널·cold-start 버퍼가 들어갔다.

- **필터는 비대칭이다**: 열기(`ACTION_VIEW`)는 넓게(`text/plain`·`application/octet-stream`·
  와일드카드 포함), 공유(`ACTION_SEND`)는 CSV mime 셋만. 사용자가 파일을 **명시적으로 고른**
  경로는 넓게 받고, 공유 목록은 깨끗하게 유지한다. 대가는 양쪽에 있다 — 열기 목록에는 CSV가
  아닌 파일로도 뜨고(Dart가 조용히 버린다), CSV를 `text/plain`으로 보내는 앱의 '공유'에서는
  안 뜬다. 실측 확인: `pm query-activities`로 SEND `text/csv` ○ / VIEW `text/plain` ○ /
  SEND `text/plain` **0건**, `dumpsys`로 등록된 필터 두 개 육안 대조.
- ⚠️ **Android는 경로가 아니라 `content://` URI를 준다.** 확장자가 없는데 Dart의
  `_handleSharedFile`은 `.csv`로 끝나지 않는 경로를 **조용히 버린다**. 그래서
  `copyToCache`가 스트림을 캐시로 복사하며 **확장자를 강제**하고 `DISPLAY_NAME`으로
  파일명을 살린다(실측: `작년업무.csv` 4472바이트가 그대로 들어왔다).
- ⚠️ **`isExternalFileIntent`에 `content` scheme이 필요하다.** Flutter 임베딩이 인텐트 URI를
  **초기 라우트로도** 넘기는데 `content://media/external/file/1000000018`은 scheme도 확장자도
  기존 조건에 안 걸려 **`GoException: no routes for location`**으로 Page Not Found가 떴다.
  판정을 순수 함수로 빼고 `test/core/router/external_file_intent_test.dart`가 고정한다.
- **가드**: `test/features/import/android_share_wiring_test.dart` 7건(매니페스트 필터 폭 ·
  채널 이름·메서드 양방향 · 확장자 강제 · `DISPLAY_NAME` · `onNewIntent` · 버퍼).

#### 이 기능이 남긴 교훈 — 가드가 통과해도 화면은 깨질 수 있다

가드 7건 · APK 빌드 · 네이티브 캐시 복사가 **전부 통과한 뒤에도** 화면은 Page Not Found였다.
라우터 조건은 Dart라 가드로 잡을 수 있었는데 **그 가드를 안 만들었기 때문**이고, 신호는
에뮬레이터를 띄우기 전까지 하나도 없었다. 네이티브 배선을 추가할 때는:

1. **컴파일해 볼 것.** 소스 텍스트 가드는 문법을 보지 않는다. 실제로 두 개가 나왔다 —
   KDoc 안에 와일드카드 mime을 적었더니 **별표+슬래시가 블록 주석을 닫아** 파일 전체가
   syntax error가 됐고, expression body 안에 `return`을 써서 또 하나가 걸렸다.
2. **에뮬레이터에서 끝까지 태워 볼 것.** cold-start(앱 꺼진 상태)와 running 둘 다 —
   전자는 `getPending`, 후자는 `onNewIntent`가 서로 다른 코드 경로다.
3. `file://`로 테스트하지 말 것 — Android 14에서 앱은 `/sdcard`의 `file://`를 권한 없이
   못 읽어 **코드가 아니라 테스트 벡터가 실패한다**(실측). `content://` + `am start
   --grant-read-uri-permission`이 실제 공유와 같은 조건이다.

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
  - **URL이 지금도 200인지는 검사하지 않는다**(네트워크). 그 몫은 `/store-listing`
    스킬이다 — 제출 직전에 URL 생존·문안 동기화·기준 버전·릴리즈 노트·스크린샷을 훑는다.
    실측 기준선(2026-08-13): **7개 전부 200**. Play 문서는 개인정보처리방침 URL을 포함해
    7개, App Store 문서는 6개인데 **정상적인 비대칭**이다(ASC는 방침 URL을 메타데이터
    필드로 받는다) — 가드는 출처 절만 비교하므로 이 차이에 걸리지 않는다.

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

#### Material이 그리는 컴포넌트에 `primary`를 채움으로 주면 안 된다 (2026-08-14)

`colorScheme.primary`는 `AppColors.gold`인데, **라이트에서 그건 배경 위 텍스트·아이콘용
딥골드**(`#9A7415`)다. Material의 날짜 선택은 선택 칸을 `primary`로 칠하고 `onPrimary`
(네이비)로 쓰므로 **3.57:1**이 돼 날짜가 안 읽혔다(사용자 신고).

**다크에서는 안 드러난다** — 다크는 `gold`와 `goldFill`이 **같은 값**이라 우연히 맞는다
(9.77:1). 라이트에서만 둘이 갈린다. 그래서 이 부류의 결함은 **라이트로 봐야 보인다.**

- 우리가 직접 그리는 곳은 `골드 채움 = goldFill + onGold` 규칙을 지키는데, **Material이
  그리는 것만 `primary`를 거쳐 그 규칙을 우회**하고 있었다. `datePickerTheme`·
  `timePickerTheme`으로 명시적으로 물린다(**8.37:1**). 시각 선택은 3곳(버스·알림 설정).
- ⚠️ **`colorScheme.primary` 자체는 바꾸지 않는다** — 배경 위 아이콘·텍스트로 쓰는 곳이
  많아 전역이 흔들린다.
- ⚠️ **오늘 칸은 `dayBackgroundColor`가 아니라 `todayBackgroundColor`가 칠하고, 글씨는
  `todayForegroundColor`가 쓴다.** 후자를 `gold` 고정으로 두면 **골드 위 골드**가 돼 숫자가
  통째로 사라진다. 가드가 두 번 통과했는데 화면은 깨져 있었고, **실제 렌더로 잡았다** —
  가드가 Material이 실제로 칠하는 짝이 아닌 짝을 재고 있었다.
- 가드는 `test/core/theme/picker_contrast_test.dart`(두 테마 × 대비·토큰·다이얼).
  미리보기는 `test/tools/kind_badge_preview.dart`가 **진짜 `DatePickerDialog`** 를 그린다.
  ⚠️ `AppColors`가 전역이라 **테마마다 따로 뽑아야 한다** — 한 트리에 둘을 넣으면 마지막
  팔레트가 둘 다 칠한다(실제로 다크 패널에 라이트 배지가 그려졌다).

#### 안 준 `ColorScheme` 필드는 폴백끼리 같은 색으로 수렴할 수 있다 (2026-09-04)

위 절의 후속이다. 거기서는 **준 값이 틀렸고**, 여기서는 **안 준 값이 틀렸다.**

스낵바의 **액션 글자가 라이트에서 통째로 사라져 있었다**(시뮬 실측 iPhone 17 / iOS 26.5).
접근성 트리에는 `Button`이 있는데 그 자리 픽셀이 전부 스낵바 배경색 하나였다 —
대비 **1.00:1**.

`colorScheme`을 **명시 생성자**로 만들면서 아홉 필드만 주고 나머지를 폴백에 맡긴 것이
기제다. M3 스낵바는 배경에 `inverseSurface`, 액션 글자에 `inversePrimary`를 쓰는데
(`snack_bar.dart`의 `_SnackbarDefaultsM3`), Flutter의 폴백이
`inverseSurface ?? onSurface`·`inversePrimary ?? onPrimary`라 **라이트 팔레트에서 둘 다
`#17253D`로 수렴한다**(`ink` = `navy`). 폴백 하나하나는 합리적인데 **짝이 되면 무너진다.**

- **다크는 우연히 맞았다** — `ink`가 크림이라 크림 배경에 네이비 글자가 됐다. 날짜 선택
  대비·공휴일 행 채움과 같은 부류로, **이 계열 결함은 라이트로 봐야 보인다.**
- **한 필드만 고친다**(`inversePrimary: isLight ? goldFill : navy`). 스낵바 배경과 본문
  (`inverseSurface`·`onInverseSurface`)은 폴백이 지금 맞는 값을 주고 있고, 바꾸면 사용자가
  이미 보고 있는 스낵바 모양이 함께 바뀐다. **폴백에 기댄 채로 둔다는 사실을 적어 둔다** —
  그 둘이 어긋나면 아래 가드가 실제 렌더에서 잡는다.
- 액션 색의 **방향이 테마마다 갈리는 이유**는 스낵바 배경이 반전되기 때문이다(라이트
  네이비 / 다크 크림). 그래서 `gold`도 `goldFill`도 한 토큰으로는 양쪽을 못 맞춘다 —
  라이트는 밝은 골드(8.37:1), 다크는 네이비(11.65:1)다.
- ⚠️ **오래 숨은 이유가 다른 결함에 가려져 있었다.** 발견 경로는 입력 탭 삭제의
  `실행취소`였는데, 그 스낵바는 하단 일괄 확정 pill에 덮여 있었고(2026-08-14·09-03 신고)
  **그 가림을 고치고 나서야** 액션이 보이는 자리로 올라왔다. 즉 **결함 하나를 고치면 그
  뒤에 있던 것이 처음으로 관찰 가능해진다** — 가림을 고친 변경을 검증할 때 "이제 보이는
  것"을 함께 봐야 한다.
- ⚠️ **발견 경로는 그날 사라졌고, 고칠 값은 남았다.** `실행취소`는 같은 날 걷어냈지만
  (위 "삭제 스낵바에 실행취소를 달지 않는다") 앱에는 **캘린더의 `설정에서 켜기`**(권한
  거부)가 남아 있고 같은 색을 쓴다. 즉 이 수정은 사라진 기능의 잔재가 아니라 **살아 있는
  경로**를 고친 것이다 — 발견 경로가 없어졌다고 함께 되돌리면 그 액션이 다시 사라진다.
- 가드는 `test/core/theme/snack_bar_action_contrast_test.dart` 4건(두 테마 × AA·동색금지).
  **토큰이 아니라 실제 렌더를 잰다** — 살아 있는 경로와 같은 형태(맨 `SnackBar`)로 띄워
  `TextButton`이 병합한 글자 색(`RichText.text.style`)과 스낵바 **첫 `Material`** 의 배경을
  읽는다. 날짜 선택 가드가 "Material이 칠하는 짝이 아닌 짝"을 재다 두 번 헛통과한 전례를
  따르지 않는다.

#### Android 15+ edge-to-edge — 시스템 바 스타일은 위/아래를 따로 심는다 (2026-09-03)

Play Console이 "SDK 35 타겟은 인셋을 처리해야 한다"고 안내했다. **인셋 자체는 이미 다
처리돼 있었고**(AppBar가 상단, `FloatingTabBar`의 `SafeArea(top:false)`가 하단, 시트 넷은
`useSafeArea`/`viewPadding`), 깨져 있던 것은 **내비게이션 바 아이콘 대비** 한 곳이다.

Android 16(API 36) 에뮬레이터 실측 — 3버튼 내비게이션에서 **back/home/recents가 안 보인다**:

| 내비게이션 | 테마 | 스트립 | 버튼 | 대비 |
|---|---|---|---|---|
| 3버튼 | 라이트 | `#FFFFFF` | `#FFFFFF` | **1.00:1** |
| 3버튼 | 다크 | `#D0D4DA`(80% 스크림) | `#FFFFFF` | **1.49:1** |
| 제스처 | 양쪽 | 탭바 색 그대로 | 자동 대비 | 정상 |

- **원인은 `SystemUiOverlayStyle.dark`/`.light`가 양쪽 다 흰 아이콘 + 검정 바를 담고 있다는
  것이다**(`system_chrome.dart:316-330`). API 34까지는 검정 바가 실제로 칠해져 맞았는데,
  API 35+가 `systemNavigationBarColor`를 무시하면서 흰 아이콘만 남았다. **`targetSdk`는
  `flutter.targetSdkVersion` = 36이고 API 36에는 빠져나갈 방법이 없다**(`FlutterExtension.kt:34`,
  `system_chrome.dart:606`).
- **제스처에서만 멀쩡했던 것이 이 결함이 오래 숨은 이유다.** 핸들은 SystemUI가 뒤 화면을
  샘플링해 색을 고르고, 3버튼 버튼은 앱이 선언한 플래그만 따른다. 제스처를 쓰는 사용자는
  이 증상을 볼 수 없다.
- 이 계열 결함은 **라이트로 봐야 보인다** — 날짜 선택 대비·공휴일 행 채움과 같은 부류다.
  다크는 우연히 덜 나쁘다.
- ⚠️ **Play 안내문의 `enableEdgeToEdge()`는 Kotlin 네이티브용이고 Flutter에 넣으면 안 된다.**
  Flutter가 이미 자동으로 한다.

**고친 방식: `AppTheme.systemOverlayStyle(brightness)` 하나로 모으고 내비게이션 바 세 필드를
함께 덮는다.** 셋이 다 필요하다 — 아이콘 밝기(반전) · `contrastEnforced: false`(스크림을
끄지 않으면 위 대비 계산의 전제인 "이 영역 = 탭바 색"이 무너진다) · `color: transparent`
(API 35+는 무시하지만 minSdk 24라 Android 7~14에는 아직 검정 바가 칠해져, **아이콘만
뒤집으면 구버전이 대신 깨진다**). 셋을 함께 두면 API 24~36이 한 규칙이다.
실측 결과 라이트 5.74:1 · 다크 14.74:1, 다크에서는 회색 스크림 띠도 사라졌다.

- **`SystemOverlayRegion`(루트 `AnnotatedRegion`)이 필요한 이유**: 프레임워크는 화면 위쪽과
  아래쪽에서 리전을 **따로** 찾는다(`view.dart:429`). 이 앱의 리전은 `AppBar`가 자동으로
  만드는 것 하나뿐이었고 그건 위쪽에만 있어서, 아래가 비면 프레임워크가 편의상 위쪽 것으로
  내비게이션 바 속성까지 채운다(`view.dart:466`) — **AppBar 하나가 내비게이션 바 색까지
  정하고 있었다.** 루트에 깔면 역할이 갈리고(상태바=AppBar, 내비게이션 바=루트),
  **`AppBar`가 없는 화면(온보딩)도 덮인다** — 거기는 리전이 아예 없어 프레임워크가 이전 값을
  그대로 유지했다(`view.dart:443` 조기 반환).
- 자리는 `MaterialApp`의 `builder`다. 그래야 라우트와 그 위에 뜨는 시트·다이얼로그까지 같은
  Navigator 안에 들어온다.
- ⚠️ **`SystemOverlayRegion`은 Android 전용이 아니다.** 프레임워크는 **아래쪽 리전만**
  Android에서 건너뛰고(`view.dart:432`), 위쪽은 두 플랫폼 다 샘플링한다. 이 리전이 화면 전체를
  덮으므로 **iOS에서도 `AppBar` 없는 화면의 상태바 스타일을 이 리전이 공급한다** — 예전에는
  위·아래가 모두 null이라 조기 반환으로 직전 값이 남았다. iOS 실측(iPhone 17 / iOS 26.5)에서
  온보딩 상태바가 라이트 19.74:1 · 다크 18.13:1로 옳게 나온다. 이름에 `nav`를 넣지 않은 이유다.
- 가드는 `test/core/theme/system_overlay_style_test.dart` 9건. **아이콘 색과
  `AppColors.surface`의 실제 대비를 4.5:1로 재므로**, 팔레트를 뒤집으면 아이콘도 뒤집으라고
  말해준다. 위젯 테스트는 `SystemChrome.latestStyle`로 **플랫폼까지 도달한 값**을 본다.
  - ⚠️ `latestStyle`는 전역 static이고 리전이 없으면 프레임워크가 **조용히 이전 값을
    유지**한다 → 배선이 빠져도 통과한다. 그래서 먼저 틀린 값으로 **오염시켜** 둔다.
  - `app.dart`가 실제로 감싸는지는 소스 문자열로 검사한다(위젯 테스트는 조립을 흉내낼 뿐이라
    앱이 그렇게 조립하는지는 못 잡는다).
- ⚠️ **전환 중 프레임을 실측값으로 오해하지 말 것.** 테마를 바꾼 직후 캡처하면 내비게이션 바가
  옛 색으로 잡힌다(실제로 한 번 오진했다). 라이브 전환 자체는 양방향으로 확인했다 —
  `builder`가 매 `build`마다 새 값을 심는다.
- ⚠️ **가로 회전은 두고 본다**(사용자 결정 2026-09-03). 3버튼 내비게이션이 측면으로 가면
  본문이 그 아래로 들어가고 `AppBar` 제목이 전체 폭 기준으로 중앙 정렬된다. 탭바는
  `SafeArea`가 좌우까지 처리해 정상이다. 세로 전용 폰 앱이라 실제로 가려지는 것은 대부분
  빈 여백이어서 고치지 않았다 — 손대려면 본문에 좌우 `SafeArea`를 넣는다(화면 9곳).

#### `faint`는 알파와 색을 테마별로 따로 잡는다 — 여기선 다크가 더 나빴다 (2026-09-03)

위 내비게이션 바를 재던 중 **탭바 미선택 라벨**(`오늘`·`캘린더`·`입력`·`설정`, 10px w400 =
`AppColors.faint`)이 **양 테마 모두 AA 미달**로 드러났다. 사용자 신고("탭 글씨 안 보인다")로
확인된 값이다.

| | 수정 전 | 수정 후 |
|---|---|---|
| 라이트 | `#7E8696` → 흰 탭바 **3.66:1** | `#646C7A` → **5.29:1** |
| 다크 | 35% 크림 → 네이비 **2.76:1** | 60% 크림 → **5.33:1** |

- ⚠️ **이 리포에서 처음으로 다크가 더 나쁜 대비 결함이다.** 날짜 선택·공휴일 행·종류 배지는
  전부 "라이트로 봐야 보인다"였는데 여기는 반대다. 이유는 다크 `faint`가 **알파 크림**이라는
  것 — **알파 토큰은 배경이 진할수록 대비를 잃는다.** 그래서 "라이트만 확인하면 된다"는
  경험칙을 여기까지 밀면 안 된다.
- **한 값으로 두 테마를 못 맞춘다**: 라이트는 색을 진하게, 다크는 알파를 올린다. 공휴일 행
  채움과 같은 결론이다.
- ⚠️ **최악 배경은 `surface`(흰 카드)가 아니라 `surfaceVariant`다.** `app_theme.dart`가
  입력칸을 `fillColor: surfaceVariant`로 칠하면서 `hintStyle`에 `faint`를 주므로(:155·:169)
  그 조합이 실재한다. 가드는 `surface`·`background`·`surfaceVariant` **셋 다** 본다.
- **위계도 함께 잠근다** — 대비를 올리다 `sub`를 넘으면 보조 텍스트와 흐린 텍스트가 뒤집힌다.
  가드가 세 배경에서 `faint < sub < ink`를 검사한다.
- **대가: `faint`는 본문 글씨와 장식 아이콘을 겸하는 토큰이라 장식도 함께 진해진다.**
  빈 상태의 64px `Icons.event_note`가 그 예로, 다크에서 `#5A6066 → #949592`가 됐다
  (실측). 글씨 가독성과 맞바꾼 것이지 사고가 아니다 — 조용하게 되돌리려면 `faint`가 아니라
  **탭바/힌트용 텍스트 토큰을 분리**해야 한다(45곳이 `faint`를 쓴다).
- 가드는 `test/core/theme/faint_contrast_test.dart` 4건. **알파를 `Color.alphaBlend`로
  합성해서 잰다** — 합성하지 않으면 `computeLuminance()`가 알파를 무시해 다크가 실제보다
  좋게 나온다(2.76:1이 통과해 버린다).
- **두 플랫폼 실측이 소수점까지 같다**(Android 16 에뮬레이터 / iPhone 17·iOS 26.5 시뮬레이터,
  각각 전·후 빌드). `faint`는 Dart 색이라 당연하지만, 이 확인이 **팔레트 변경은 한쪽에서만
  검증해도 된다**는 근거가 된다 — 플랫폼이 개입하는 것은 시스템 바(위 절)뿐이다.
  iOS에서 실제로 변한 곳은 픽셀 차분으로 세 군데였다: 히어로 가운데 칸(`AI 앱`) ·
  검토 대기 칩의 chevron · 탭바 미선택 라벨.

## 배포 · 빌드 도구

명령·레인·게이트·트러블슈팅·검증 함정은 **`.claude/skills/deploy/SKILL.md`** 런북에 있다
(`/deploy`로 부른다). 여기 남기는 것은 **배포 밖에서도 밟는** 급소 셋과, 배포가 아닌 도구 하나다.

- **`pubspec.yaml`의 `+N`은 안드로이드 전용 하한이다.** iOS는 이 값을 읽지 않는다.
  한 필드가 두 플랫폼에서 **다른 뜻**을 갖는 것이 함정의 뿌리다 — iOS에서 무해하니 손으로
  올려도 된다고 생각하면 **다음 안드로이드 업로드가 그 값으로 튀고 versionCode는 감소할 수
  없다**(실측: Play가 54인데 하한이 143이었다). 두 스토어 번호를 맞추려면 하한을
  `TestFlight 최신 + 1`로 둔다. 계산식·정렬 마모·거부된 빌드가 번호를 먹는 함정은 런북.
- **Android `beta`는 업로드 즉시 Play 심사로 들어간다**(`release_status: "completed"`).
  트랙 `internal`은 비공개 테스트 14일 요건을 **하루도 세지 않는다** — 착각하면 되돌릴 수 없다.
- **실기기 확인은 `internal` 레인이다**(iOS `beta`=TestFlight 자리). 심사를 기다리지 않아
  반복해도 심사를 소모하지 않는다. 대가는 **versionCode를 영구히 소비**하는 것 —
  Play는 앱 단위로 유일성을 요구해 트랙별 번호 공간이 없고, `VERSION_SCAN_TRACKS`에
  internal이 있어 다음 `beta`가 그보다 큰 값을 받는다. 즉 **위 "하한을 TestFlight 최신
  + 1로 둔다"는 정렬이 internal 확인 횟수만큼 앞서간다.**
- ⚠️ **iOS와 Android 레인을 동시에 돌리지 않는다.** Android `build_aab`의
  `reset_android_caches`가 `flutter clean`으로 **`build/`와 `.dart_tool/`을 통째로 지운다**.
  iOS도 같은 `build/`에 ipa를 만들어, 병행하면 한쪽이 조용히 깨진다.
  **iOS 먼저, Android 나중** — 지우는 쪽을 뒤에 둔다.
- **수동 `flutter build ipa`로는 배포하지 않는다.** `--dart-define-from-file`이 없어 **TAGO 키가
  빠진 IPA**가 나오는데, release 레인의 가드 넷 어디도 키를 보지 않아 **버스 기능이 조용히 죽은
  빌드가 심사에 오른다**. 캐시만 비우고 **다시 `beta` 레인으로** 빌드한다.

### 배포 문서는 가드가 지킨다

`test/deploy/fastlane_lane_docs_test.dart`가 두 Fastfile의 `lane :`과 **CLAUDE.md +
`.claude/skills/*/SKILL.md` 전부**의 `<platform>/bin/fastlane.sh <이름>`을 **양방향** 대조한다.
없는 명령을 적으면 깨지고, 레인을 추가하고 문서에 안 적어도 깨진다. 면제(`_internalLanes`)에는
이유를 함께 적는다 — 목록을 늘려 통과시키면 역방향 검사가 무력해진다. 승격 경위와 일반 규칙은
`/guard` 스킬에 있다.

- ⚠️ **`upload_screenshots`·`check_screenshots`·`dedupe_screenshots`라는 레인은 없다.**
  문서가 셋을 명령으로 적어둬서 스크린샷을 확인하려던 세션이 `Could not find lane`으로
  헛돌았다(2026-08-06). **iOS 레인은 일곱 개**이고 목록은 런북에 있다.
- ⚠️ 스킬을 새로 만들면 **그 파일도 이 가드의 대상**이다(손으로 목록에 적지 않고 훑는다).
  훑기가 죽으면 검사 대상이 CLAUDE.md 하나로 조용히 줄어들어, 생존 테스트가 그것도 본다.

### 앱 아이콘 재생성

```
flutter test test/tools/gen_app_icon.dart   # 1024x1024 원본 갱신
dart run flutter_launcher_icons              # 각 iOS 사이즈 재생성
```

- `test/tools/gen_app_icon.dart`는 파일명에 `_test`가 없어 `flutter test` 자동 스캔에서
  제외된다. 명시 지정할 때만 실행된다.

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

⚠️ **이 리포에는 git 훅이 없다**(`.git/hooks/`에 샘플뿐, 실측 2026-09-03). 그래서
`--no-verify`를 막는 근거는 "커밋 훅을 건너뛴다"가 **아니고**, 전역 규칙상 사전 확인
대상이라는 것 하나다(차단 자체는 유효하다 — 근거만 낡아 있었다). `git commit`·`git push`에
자동으로 붙는 것은 아무것도 없다 — `simplify`·`verifier`·`code-review`는 **부를 때만** 돈다.

**종료 코드가 곧 정책이다**: `0` 통과(stdout은 디버그 로그로만 간다 — 아무도 못 본다) /
`2` 차단(stderr **전문**이 Claude에게) / **그 밖은 비차단 경고**(실행은 계속되고
transcript에 stderr **첫 줄만** 뜬다 — 그래서 경고 문구는 한 줄로 쓴다).

### deny는 "위험한가"가 아니라 "정당한 사용이 0인가"로 정한다

- **`bootstrap`·force push·`--no-verify`·`test|integration_test|lib`를 지우는 `rm`**
  → 무조건 차단. 정당한 사용이 없거나(패키지명은 확정됐다) 사용자가 직접 하면 된다.
- **`rm -rf build ios/Pods`는 막지 않는다** — 이 리포의 정상 절차(수동 캐시 리셋)다.
- **`android beta`는 막지 않는다.** 정당한 사용이 있는 명령을 매번 막으면 마찰이 쌓이고,
  **마찰은 훅을 지운다**(그러면 `bootstrap` 차단까지 함께 사라진다). 대신 전제조건을 본다.

### `beta` 게이트가 보는 것과 보지 않는 것

`flutter analyze` + **배포 가드 테스트만**(`test/deploy` + `data_source_credit_test`).
실측 warm 10.2초. 전체 1070건은 배포 리듬을 해쳐 뺐다 — **기능 회귀는 이 게이트가 잡지
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

#### 같은 함정이 이 리포에서 세 번 났다 — 스캐너는 언급과 사용을 구별하지 못한다

| 스캐너 | 언급했을 뿐인데 | 결과 |
|---|---|---|
| 훅의 위험 패턴 검사 | 커밋 메시지가 `--no-verify`를 설명 | 커밋이 차단됐다 |
| 스토어 가드의 절 추출 | 변경 이력 표가 절 제목을 재언급 | 절 대신 표를 검사(URL 0개) |
| 스킬 로더의 동적 주입 | 스킬 본문이 주입 문법을 예시로 적음 | **그 예시가 실행됐다** (`command not found: cmd`) |
| Kotlin 블록 주석 | KDoc이 와일드카드 mime을 그대로 적음 | 별표+슬래시가 **주석을 닫아** 파일 전체가 syntax error |

셋 다 "문자열이 있으면 그것을 하려는 것"이라고 가정했다. **마크다운 코드스팬은 보호가
아니다** — 로더도 grep도 원문을 본다. 새 스캐너를 붙일 때는 **자기 자신을 설명하는
문서를 입력으로** 한 번 넣어 볼 것. 이 리포에서 그때마다 걸렸다.

**스킬 로더의 트리거 조건은 좁다**(관측 둘로 추정, 문서 근거는 없다): `!`가 **공백이나
줄머리 뒤**에 있고 그 다음이 **여는** 백틱일 때만 실행된다.

- 그래서 `` `dedupe_screenshots!` ``·`` `app.ensure_version!` ``처럼 **코드스팬이 `!`로
  끝나는 것은 안전하다** — `!` 앞이 단어문자다. deploy 스킬에 그 형태가 세 곳 있는데
  스킬을 실제로 로드해 **오류 없음을 확인했다**(2026-08-13). 배포 런북은 위험하지 않다.
- 실패한 쪽은 `!` 앞이 공백이었다. 즉 **문장 중간에 예시로 적을 때가 정확히 위험한 자리**다.
- 인자(`args`)로 넘길 때는 하니스가 **공백을 끼워 무력화한다**(실측: `identifier!`+백틱이
  `identifier! `+백틱으로 도착했다). 본문과 인자의 처리가 다르다.

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
- **`GoldGradientButton`은 좌우 padding 24를 스스로 갖는다** — 가운데 정렬하려면 `Center`로
  감싼다. (구조 트리를 `docs/notes/`로 옮길 때 트리 주석에만 있던 제약이라 여기로 올렸다.)
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
