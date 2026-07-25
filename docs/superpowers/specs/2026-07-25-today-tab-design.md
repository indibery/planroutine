# 오늘 탭 설계 (결재 도장 + 결산 링)

작성: 2026-07-25

## 목적

캘린더 탭은 "언제 무엇이 있나"를 보는 화면이다. 오늘 탭은 **오늘 처리할 것만 남기고 눌러서
지워내는 화면**이다. 완료 처리가 지금은 왼쪽 스와이프뿐이라 발견성이 낮고, 완료했을 때
아무 보상이 없다.

체크 원 탭으로 완료하고, 완료 순간에 **결재 도장이 찍히는 이펙트**(개별 보상) + **상단 결산
링이 차오르는 연출**(전체 보상)을 준다. 보상이 행과 화면 두 층에 걸려서 한 건만 눌러도
즐겁고, 다 비우면 확실히 닫히는 느낌이 온다.

## 확정된 결정

| 항목 | 결정 | 근거 |
|---|---|---|
| 대상 | 캘린더 이벤트만 (`calendar_events`) | `completed_at`이 이벤트에만 있음. 검토 탭(pending)과 역할 분리. 확정 시 이벤트가 생기므로 실질 누락 없음 |
| 탭 순서 | 오늘 · 캘린더 · 검토 · 설정 | 매일 쓰는 화면을 기본으로. 초기 라우트도 `/today` |
| 도장 문구 | "완료" | "결재"는 상급자 승인을 뜻해 본인 업무 완료에 어색 |
| 지난 항목 범위 | **롤링 7일** (오늘−7일 ~ 어제) | 월~일 캘린더 주로 하면 월요일엔 비고 일요일엔 13일치가 쌓여 예측 불가 |
| 진행도 링 | **오늘 항목만** 계산 | 지난 항목이 섞이면 "오늘 다 닫았습니다"에 도달 불가 |
| 완료 항목 위치 | 탭한 자리 고정, 재진입 시 정렬 | 즉시 재정렬하면 도장 애니메이션이 화면 밖에서 재생됨 |
| 기간 이벤트 | `event_date` 기준만 | 캘린더 탭과 동일. 다르게 하면 두 탭이 서로 다른 답을 냄 |

### 왜 롤링 7일 컷오프가 필요한가

공직플랜은 작년 CSV를 임포트해 올해 일정을 만드는 앱이다. 임포트 직후 DB에는 **이미 날짜가
지난 미완료 이벤트가 수십~수백 건** 쌓여 있다. 지난 항목을 전부 올리면 오늘 탭을 여는 순간
지난 목록에 파묻혀 "오늘"이 화면 밖으로 밀려난다. 7일 컷오프 + 기본 접힘으로 막는다.

## 아키텍처

DB 스키마 변경 없음. `CalendarRepository` 변경 없음 — 기존 `getEventsByDateRange`로
`오늘−7일 ~ 오늘`을 조회하고 순수 함수로 가른다.

```
lib/features/today/
├── domain/
│   ├── today_view.dart                  # TodayView + buildTodayView() ← 순수 함수
│   └── stamp_settings.dart              # SealStyle + StampSettings (도장 설정)
└── presentation/
    ├── screens/today_screen.dart        # provider 배선만 (얇은 조합)
    ├── providers/today_providers.dart   # todayReferenceProvider, TodayViewNotifier
    └── widgets/
        ├── today_body.dart              # 순수 위젯 (view + 콜백) ← 위젯 테스트 대상
        ├── today_progress_ring.dart     # CustomPainter 링 + 카운트업 + 완주 펄스/햅틱
        ├── today_event_row.dart         # 체크 원 + 제목 + 도장 슬롯
        ├── completion_seal.dart         # 완료 도장 3종 (애니메이션)
        └── midnight_watcher.dart        # 자정 넘김 시 기준일 갱신 (app.dart가 감쌈)
lib/core/constants/strings/today_strings.dart
```

`buildTodayView`는 `computeNotifications`와 같은 패턴이다 — DB·플랫폼 무관 순수 함수라
정렬·컷오프 규칙이 한 곳에 모이고 유닛 테스트가 쉽다.

`TodayView`는 `PendingNotification`과 같이 freezed 없는 순수 클래스로 둔다(계산 결과 뷰이며
직렬화가 필요 없다).

### 데이터 흐름

```
todayReferenceProvider (DateTime.now, 테스트에서 override)
        ↓
TodayViewNotifier.build()
        ↓ getEventsByDateRange(오늘−7일, 오늘)
buildTodayView(events, today)  ← 순수
        ↓
TodayScreen → TodayBody(view, onToggle) → TodayProgressRing / TodayEventRow
```

### 2026-07-25 후속 수정 (실기기 피드백)

| 항목 | 변경 | 이유 |
|---|---|---|
| 완주 문안 | "오늘 업무를 모두 닫았습니다" → **"오늘 업무 모두 완료했네요!"** | "닫았다"는 잘 쓰지 않는 표현 |
| 화면 구조 | 본문 큰 제목 → **AppBar(eyebrow `TODAY` + 제목)** | 캘린더·검토 탭이 모두 AppBar를 써서 오늘 탭만 이질적이었다 |
| 일정 등록 | **골드 FAB 추가** (`shared/widgets/gold_fab.dart`) | 오늘 탭에서도 등록 가능해야 한다. 캘린더 탭 FAB를 같은 위젯으로 추출해 공유 |
| 갱신 버그 | **`eventsRevisionProvider` 도입** | 캘린더에서 추가한 오늘 일정이 오늘 탭에 안 나타났다 |
| provider 수명 | `todayViewProvider`를 **autoDispose로** | 평범한 `ShellRoute`라 탭 전환 시 화면은 dispose되는데 provider가 남아 재진입 시 옛 목록이 보였다 |

`eventsRevisionProvider`는 캘린더 CRUD가 올리는 신호이고, 오늘 탭이 watch해 스스로
재조회한다. 캘린더 provider가 오늘 탭 provider를 직접 invalidate하면 feature 간 순환
참조가 되므로 신호만 올린다. **단 `TodayViewNotifier.toggleCompleted`는 리비전을 올리지
않는다** — 올리면 자기 build가 다시 돌아 자리 고정이 깨진다.

### 2026-07-25 완료 도장 설정 (3종 + 흐리게)

도장이 여러 개 쌓이면 목록이 시끄럽다는 피드백 → 설정으로 뺐다.

`설정 탭 > 완료 도장` (`StampSettingsTiles`):

| 설정 | 값 | 기본 |
|---|---|---|
| 도장 모양 | 완료(원형·글자) / 결재(사각·글자) / 좋아요(원형·엄지 아이콘) | 완료 |
| 이미 찍은 도장 흐리게 | on/off | **on** |

- `SealStyle` enum이 모양 규칙을 들고 있다(`isSquare`, `usesIcon`, `label`) —
  `CompletionSeal`은 enum만 보고 그린다. 모양을 더 늘릴 때 위젯 분기를 건드릴 필요가 없다.
- "좋아요"는 네 글자라 도장 안에 안 들어가서 **엄지 아이콘**으로 찍는다(설정 라벨만 "좋아요").
- **흐리게는 "지난 도장"에만 적용한다.** `TodayEventRow._stampedOnEntry`(행이 처음 그려질 때
  이미 완료였는지)로 구분하고, 화면에서 방금 누른 도장은 `didUpdateWidget`에서 이 플래그를
  내려 진하게 남긴다. 방금 찍은 도장까지 옅어지면 누르는 재미가 죽는다.
- 저장은 `stampSettingsProvider`(SharedPreferences, key `stamp_settings_v1`).
  설정값은 `settings/presentation/providers`에 두고 소비자가 import하는 기존 관례를 따랐다
  (`calendar_target_provider` 선례). 도메인(`SealStyle`/`StampSettings`)은 `today/domain`.

### 2026-07-25 자정 넘김 대응

`todayReferenceProvider`는 부팅 시점 `DateTime.now()`를 캐시하고 autoDispose가 아니라 탭을
옮겨도 살아 있다. 그대로 두면 앱을 켜둔 채 자정을 넘긴 뒤에도 오늘 탭이 계속 어제를 기준으로
조회한다(`todayViewProvider`가 재조회돼도 기준일이 어제라 결과가 어제다).

- `MidnightWatcher`(`app.dart`가 `MaterialApp`을 감쌈)가 **앱 복귀 시에만** 날짜를 비교하고,
  **바뀌었을 때만** 무효화한다. 복귀마다 무효화하면 같은 날에도 DB 재조회가 매번 일어난다.
- ⚠️ `late String _lastSeenDate = ...` 같은 **필드 초기화식은 첫 읽기까지 지연된다.** 그 첫
  읽기가 복귀 콜백 안이면 이미 자정 지난 시각으로 초기화돼 "안 바뀌었다"고 판단한다 →
  `initState`에서 즉시 채운다. (`TodayEventRow._stampedOnEntry`도 같은 함정)
- **FAB은 캐시된 기준일이 아니라 누른 시점의 `DateTime.now()`** 로 일정을 만든다. 기준일을
  넘기면 자정 직후 어제 날짜로 일정이 등록된다.
- **미대응**: 포그라운드로 켜둔 채 자정을 넘기는 경우(복귀 이벤트가 없다). 화면을 벗어났다
  들어오면 `todayViewProvider`는 재조회되지만 기준일은 그대로다.

### 완료 토글

`TodayViewNotifier.toggleCompleted(event)`:
1. `markCompleted` / `markIncomplete` 호출
2. **자리 고정 갱신** — `view.withToggled(id, completedAt)`으로 해당 항목만 교체
   (`invalidateSelf` 금지 — 재정렬로 도장 애니메이션이 깨진다)
3. 캘린더 캐시 무효화 (`monthEventsByYearMonthProvider`, `selectedMonthEventsProvider`)
4. **알림 재동기화 필수** — `notification_rules.dart:39`가 `completedAt == null`로 완료
   이벤트를 알림 대상에서 제외한다. sync를 빠뜨리면 처리한 일이 다음 월요일 종합 알림에 남는다

## 화면 규칙

| 영역 | 규칙 |
|---|---|
| 지난 섹션 | 오늘−7일 ~ 어제 · 조회 시점 미완료만 · **기본 접힘** + 개수 pill |
| 오늘 섹션 | 오늘 날짜 전체 (완료 포함) · 중요 미완료 → 일반 미완료 → 완료 순 |
| 진행도 링 | 오늘 항목만 `done/total` |
| 완료 항목 | 그 자리에 남아 흐려짐 + 취소선 → 재탭으로 즉시 되돌리기 |
| 오늘 0건 | 링 숨기고 "오늘 예정된 일정이 없습니다" |
| 체크 원 | 시각 24px, **탭 영역 44×44** (iOS HIG 최소치) |
| 도장 자리 | 행 우측 56px 확보, 제목은 그 앞에서 ellipsis |

## 애니메이션

| 단계 | 값 |
|---|---|
| 행 눌림 | 340ms `scale 1 → 0.975 → 1` + `HapticFeedback.mediumImpact()` |
| 도장 낙하 | 460ms `scale 2.4 → 0.92 → 1.05 → 1.0` / `rotate −26° → −10°` / `opacity 0 → 0.88` |
| 링 충전 | 550ms `Curves.easeOutCubic` + 숫자 카운트업 |
| 완주 | 링 골드 펄스 700ms + `HapticFeedback.heavyImpact()` + "오늘 업무 모두 완료했네요!" |
| 완료 취소 | 도장 200ms 페이드아웃 — **낙하의 역재생이 아니다.** `AnimationStatus.reverse`를 보고 scale/rotate를 안착값에 고정하고 불투명도만 감쇠한다(역재생하면 사라지는 동안 도장이 부풀어 제목을 덮는다) |

색은 전부 `AppColors` 토큰: 도장 테두리·링 값 `goldFill`, 도장 문구 `gold`, 완료 텍스트 `faint`.

## 라우팅

- `AppRoutes.today = '/today'` 신설, `ShellRoute` 첫 자식
- `MainShell._tabs` 맨 앞에 추가 — `Icons.check_circle_outline` / `Icons.check_circle`, 라벨 `AppStrings.tabToday`
- `createRouter`의 초기 라우트 `AppRoutes.calendar` → `AppRoutes.today`

기존 E2E는 인덱스가 아니라 아이콘으로 탭을 찾으므로(`integration_test/app_test.dart:34` `_tapTab`)
영향이 낮다. 초기 라우트가 바뀌므로 `screenshot_test.dart`는 실행해 확인한다.

## 테스트

**유닛** (`test/features/today/today_view_test.dart`)
- 오늘/지난 분리
- 7일 컷오프 경계 (7일 전 포함, 8일 전 제외)
- 지난 항목 중 완료된 것 제외
- 오늘 정렬: 중요 미완료 → 일반 미완료 → 완료
- 진행도는 오늘 항목만 계산
- 오늘 0건 / 전부 완료
- `withToggled`가 자리를 유지한 채 완료 상태만 바꾼다

**위젯**
- `today_body_test.dart` — 체크 탭 시 콜백, 완료 항목 취소선, 지난 섹션 접힘/펼침, 빈 상태,
  도장 모양/흐리게 4경우
- `today_progress_ring_test.dart` — done/total 표시
- `today_progress_ring_pulse_test.dart` — 완주 heavyImpact 햅틱(발화/미발화/반복 방지),
  숫자 카운트업
- `completion_seal_test.dart` — 모양 3종, 문구 폭 가드, 흐리게 불투명도
- `completion_seal_reverse_test.dart` — 완료 취소가 부풀지 않고 진해지지 않는지
- `today_screen_test.dart` — AppBar 구조, FAB, 등록 시트
- `midnight_watcher_test.dart` — 복귀 시 날짜 변경/미변경/반복

**미검증으로 남긴 것** (부채)
- 6행짜리 달(예: 2026년 8월)의 주말 열 — 현재 여유 5pt로 정상이나 5행(7월)만 테스트가 있다
- `stampSettingsProvider`의 SharedPreferences 왕복 — 순수 직렬화만 검증된다
- 월/연 경계 `buildTodayView`

기존 테스트는 수정하지 않는다(단 `TodayView.progress` 제거 시 해당 단정 3개는 함께 정리).

## 범위 밖

- 검토 탭 pending 일정 노출
- 반복 일정
- 지난 항목 일괄 처리
- 완료 통계·연속 달성(streak)
