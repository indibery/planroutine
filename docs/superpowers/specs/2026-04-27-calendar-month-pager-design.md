# 캘린더 월 슬라이드 전환 설계

작성일: 2026-04-27
대상 화면: `lib/features/calendar/presentation/screens/calendar_screen.dart`

## 배경

캘린더 화면에서 가로 스와이프로 월을 전환하는 동작이 이미 있지만(`onHorizontalDragEnd`),
임계 속도를 넘으면 즉시 다음 달로 점프하는 형태라 손가락이 그리드를 끌어당기는
인터랙션 감각이 없다. iOS Calendar 앱처럼 손가락 따라 그리드가 같이 움직이고
손을 떼면 가장 가까운 월로 snap되는 슬라이딩 경험을 제공한다.

또한 헤더 가운데 작은 글씨로 표시되던 "오늘" 라벨은 시각적 노이즈로 판단되어
제거한다(탭하면 오늘로 점프하는 액션은 유지).

## 결정 요약

| 항목 | 결정 |
|------|------|
| 슬라이드 영역 | **그리드만** — 헤더와 이벤트 리스트는 새 월로 즉시 갱신 |
| 슬라이드 위젯 | `PageView.builder` 기반 신규 `CalendarMonthPager` |
| selectedDate 동기화 | `ref.listen` + 현재 페이지 비교로 무한 루프 방지 |
| 페이지 데이터 | family provider `monthEventsByYearMonthProvider` 신규 |
| 헤더 "오늘" 텍스트 | **제거** (탭 액션은 유지) |
| 기존 `onHorizontalDragEnd` | 제거 (PageView가 대체) |
| 트랜지션 곡선 | `Curves.easeOutCubic`, 280ms |

## 아키텍처

```
selectedDateProvider (StateProvider<DateTime>)
        │
        ├──→ selectedMonthEventsProvider ──→ mapProvider/groupedProvider
        │       (이벤트 리스트, 헤더 등 기존 그대로)
        │
        └──→ CalendarMonthPager
               │  ref.listen으로 변경 감지
               │
               └──→ PageController.animateToPage()
                            │
                            └──→ onPageChanged
                                   │
                                   └──→ selectedDateProvider 갱신
```

페이지마다 그리드는 자기 월 이벤트를 받아야 하므로, 신규 family provider를
도입한다. `selectedMonthEventsProvider`는 이벤트 리스트가 계속 의존하므로 그대로 유지.
두 provider가 같은 DB를 다른 캐시로 보지만, CRUD 시점에 둘 다 invalidate해 일관성을 보장.

## 컴포넌트 변경 목록

| 파일 | 변경 |
|------|------|
| `lib/features/calendar/presentation/widgets/calendar_month_pager.dart` | **신규** — PageView 래퍼, 페이지 인덱스 ↔ 월 매핑, controller, selectedDate 동기화 |
| `lib/features/calendar/presentation/widgets/page_index_mapping.dart` | **신규** — 매핑 함수 모듈 (anchor 주입형, 단위 테스트 용이) |
| `lib/features/calendar/presentation/providers/calendar_providers.dart` | `monthEventsByYearMonthProvider` family 신규. 기존 `SelectedMonthEventsNotifier`의 CRUD 메서드에서 family 함께 invalidate |
| `lib/features/calendar/presentation/screens/calendar_screen.dart` | `GestureDetector(onHorizontalDragEnd)` 제거, `CalendarMonthPager` 삽입. "오늘" Text 위젯 제거 |
| `lib/features/schedule/presentation/providers/schedule_providers.dart` | 일정 확정 → 캘린더 이벤트 생성 흐름에서 family 함께 invalidate |
| `lib/core/constants/strings/calendar_strings.dart` | `CalendarStrings.today` 상수가 캘린더 외부에서 미사용이면 제거 |

## 페이지 인덱스 ↔ 월 매핑

`page_index_mapping.dart`에 anchor 주입형 함수로 분리해 단위 테스트 용이성 확보.

```dart
const int kPagerBaseline = 1200; // ±100년 범위 확보

DateTime pageIndexToMonth({
  required int index,
  required int anchorYear,
  required int anchorMonth,
}) {
  final delta = index - kPagerBaseline;
  return DateTime(anchorYear, anchorMonth + delta, 1);
}

int monthToPageIndex({
  required int year,
  required int month,
  required int anchorYear,
  required int anchorMonth,
}) {
  return kPagerBaseline + (year - anchorYear) * 12 + (month - anchorMonth);
}
```

CalendarMonthPager는 `initState`에서 `DateTime.now()`를 anchor로 fix해 인스턴스 생애 동안 고정.

## 무한 루프 방지

`onPageChanged`와 `ref.listen(selectedDateProvider)`가 서로를 부르면 무한 호출.
**현재 페이지와 비교 후 다를 때만 명령**으로 차단.

```dart
// initState 또는 build 시 한 번
ref.listenManual(selectedDateProvider, (prev, next) {
  final targetIndex = monthToPageIndex(
    year: next.year,
    month: next.month,
    anchorYear: _anchorYear,
    anchorMonth: _anchorMonth,
  );
  final currentIndex = _controller.page?.round() ?? targetIndex;
  if (targetIndex != currentIndex) {
    _controller.animateToPage(
      targetIndex,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }
});

// PageView.builder의 onPageChanged
onPageChanged: (index) {
  final newMonth = pageIndexToMonth(
    index: index,
    anchorYear: _anchorYear,
    anchorMonth: _anchorMonth,
  );
  final current = ref.read(selectedDateProvider);
  if (current.year != newMonth.year || current.month != newMonth.month) {
    ref.read(selectedDateProvider.notifier).state = newMonth;
  }
},
```

## 외부 트리거 동기화

| 트리거 | 동작 |
|--------|------|
| 손가락 슬라이드 | PageView 자동 → `onPageChanged` → selectedDate 갱신 |
| chevron `<` `>` 탭 | selectedDate 변경 → `ref.listen` → `animateToPage` |
| 헤더 가운데 탭 (오늘로 점프) | selectedDate = today → `ref.listen` → `animateToPage` |
| schedules 일정 확정 → 캘린더 이벤트 생성 | family + selectedMonthEventsProvider 둘 다 invalidate |
| 캘린더 이벤트 CRUD | `SelectedMonthEventsNotifier`가 둘 다 invalidate |

## 엣지 케이스

| 상황 | 처리 |
|------|------|
| 앱 첫 진입 시 selectedDate=오늘 | `monthToPageIndex` = baseline(1200) → 그 페이지에서 시작 |
| 같은 월 다른 날짜 선택 (날짜 셀 탭) | `targetIndex == currentIndex` → animateToPage 호출 안 함 |
| 손가락으로 끌다가 중간에 놓음 | PageView 기본 동작 — 가장 가까운 페이지로 snap. `onPageChanged`는 snap 완료 후 1회 |
| 옆 월 데이터 깜빡임 | A안에선 옆 페이지가 화면 밖이라 시각 영향 작음. Riverpod family 자동 캐싱으로 두 번째 방문 즉시 |
| ±100년 초과 jump | 발생하지 않는 시나리오로 간주 (사용자 패턴 밖) |

## 테스트 계획

### 페이지 인덱스 매핑 단위 테스트
`test/features/calendar/presentation/page_index_mapping_test.dart`

- `pageIndexToMonth(baseline)` == anchor 월
- `monthToPageIndex(anchor.year, anchor.month)` == baseline
- baseline + 1 → anchor 다음 달
- baseline + 12 → anchor 같은 월, +1년
- baseline - 1 → anchor 이전 달
- 12월 → 1월 경계: anchor=2026/12, index=baseline+1 → 2027/1
- 1월 → 12월 경계: anchor=2026/1, index=baseline-1 → 2025/12

### PageView 위젯 자체

추가 안 함. Flutter `PageView`는 검증된 위젯이고, 우리 코드는 매핑 함수와
`ref.listen` 와이어링이 핵심. 매핑은 단위 테스트로, 와이어링은 통합 테스트(시뮬레이터)
또는 수동 검증으로 확인.

### 회귀

- 기존 단위 테스트 120개 + 신규 매핑 테스트 통과
- `flutter analyze` 깨끗
- 통합 테스트 11 시나리오는 시뮬레이터 환경 비용으로 인해 본 작업에선 단위 테스트로 회귀 갈음.
  TestFlight 내부 테스트에서 사람 눈으로 슬라이드 동작 검증.

## 의도적으로 다루지 않는 항목

- **B안 그리드+리스트 함께 슬라이드** — 제스처 충돌 처리, 양쪽 prefetch 부담으로 별개 작업으로 보류
- **양방향 prefetch 직접 구현** — Riverpod family 자동 캐싱으로 충분
- **±100년 초과 jump 시 baseline 재정렬** — 발생 가능성 없음으로 간주
- **Android 동작 검증** — 프로젝트 정책상 iOS만 출시 대상

## 출시 영향

- DB 스키마 변경 없음
- 기존 사용자 데이터 호환
- 1.0.1.x 패치로 배포 가능
