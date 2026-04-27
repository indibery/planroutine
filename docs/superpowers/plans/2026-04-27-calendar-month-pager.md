# 캘린더 월 슬라이드 전환 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 캘린더 월 전환을 PageView 기반 슬라이딩 인터랙션으로 바꾸고, 헤더 "오늘" 텍스트 라벨을 제거.

**Architecture:** 페이지 인덱스 ↔ 월 매핑 함수를 별도 모듈로 분리해 단위 테스트 용이성 확보. `CalendarMonthPager`(ConsumerStatefulWidget)가 PageController + `ref.listenManual(selectedDateProvider)`로 외부 트리거와 양방향 동기화. 페이지마다 `monthEventsByYearMonthProvider` family를 watch해 자기 월 이벤트 표시.

**Tech Stack:** Flutter `PageView.builder`, Riverpod `FutureProvider.family`, 기존 `CalendarGrid` 위젯 재사용.

**Spec:** `docs/superpowers/specs/2026-04-27-calendar-month-pager-design.md`

---

## File Structure

| 종류 | 경로 | 책임 |
|------|------|------|
| Create | `lib/features/calendar/presentation/widgets/page_index_mapping.dart` | 페이지 인덱스 ↔ (year, month) 매핑 순수 함수 |
| Create | `test/features/calendar/presentation/page_index_mapping_test.dart` | 매핑 함수 단위 테스트 |
| Create | `lib/features/calendar/presentation/widgets/calendar_month_pager.dart` | PageView 래퍼 + selectedDate 동기화 |
| Modify | `lib/features/calendar/presentation/providers/calendar_providers.dart` | `monthEventsByYearMonthProvider` family 신규. `SelectedMonthEventsNotifier` CRUD에 family invalidate 추가 |
| Modify | `lib/features/calendar/presentation/screens/calendar_screen.dart` | `GestureDetector(onHorizontalDragEnd)` 제거, `CalendarMonthPager` 삽입. "오늘" Text 위젯 제거. invalidate 호출처(라인 306)에 family 추가 |
| Modify | `lib/features/schedule/presentation/providers/schedule_providers.dart` | 캘린더 invalidate 호출 3곳에 family 추가 |
| Modify | `lib/features/settings/presentation/providers/settings_providers.dart` | 라인 49 invalidate 옆에 family 추가 |
| Modify | `lib/features/trash/presentation/providers/trash_providers.dart` | 라인 53 invalidate 옆에 family 추가 |
| Modify | `lib/features/import/presentation/providers/import_providers.dart` | 라인 173 invalidate 옆에 family 추가 |
| Modify | `lib/core/constants/strings/calendar_strings.dart` | `CalendarStrings.today` 상수 제거(미사용) |

---

### Task 1: 페이지 인덱스 매핑 모듈

**Files:**
- Create: `lib/features/calendar/presentation/widgets/page_index_mapping.dart`
- Test: `test/features/calendar/presentation/page_index_mapping_test.dart`

- [ ] **Step 1: 실패 테스트 작성**

```dart
// test/features/calendar/presentation/page_index_mapping_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/calendar/presentation/widgets/page_index_mapping.dart';

void main() {
  group('pageIndexToMonth', () {
    test('baseline은 anchor 월', () {
      final m = pageIndexToMonth(
        index: kPagerBaseline,
        anchorYear: 2026,
        anchorMonth: 4,
      );
      expect(m.year, 2026);
      expect(m.month, 4);
    });

    test('baseline + 1 → anchor 다음 달', () {
      final m = pageIndexToMonth(
        index: kPagerBaseline + 1,
        anchorYear: 2026,
        anchorMonth: 4,
      );
      expect(m.year, 2026);
      expect(m.month, 5);
    });

    test('baseline - 1 → anchor 이전 달', () {
      final m = pageIndexToMonth(
        index: kPagerBaseline - 1,
        anchorYear: 2026,
        anchorMonth: 4,
      );
      expect(m.year, 2026);
      expect(m.month, 3);
    });

    test('12월 → 1월 경계', () {
      final m = pageIndexToMonth(
        index: kPagerBaseline + 1,
        anchorYear: 2026,
        anchorMonth: 12,
      );
      expect(m.year, 2027);
      expect(m.month, 1);
    });

    test('1월 → 12월 경계', () {
      final m = pageIndexToMonth(
        index: kPagerBaseline - 1,
        anchorYear: 2026,
        anchorMonth: 1,
      );
      expect(m.year, 2025);
      expect(m.month, 12);
    });
  });

  group('monthToPageIndex', () {
    test('anchor 월은 baseline', () {
      expect(
        monthToPageIndex(
          year: 2026,
          month: 4,
          anchorYear: 2026,
          anchorMonth: 4,
        ),
        kPagerBaseline,
      );
    });

    test('anchor + 12개월 = baseline + 12', () {
      expect(
        monthToPageIndex(
          year: 2027,
          month: 4,
          anchorYear: 2026,
          anchorMonth: 4,
        ),
        kPagerBaseline + 12,
      );
    });

    test('anchor - 1개월 = baseline - 1 (역방향)', () {
      expect(
        monthToPageIndex(
          year: 2026,
          month: 3,
          anchorYear: 2026,
          anchorMonth: 4,
        ),
        kPagerBaseline - 1,
      );
    });

    test('round-trip: monthToPageIndex(pageIndexToMonth(i)) == i', () {
      for (final delta in [-24, -1, 0, 1, 12, 100]) {
        final m = pageIndexToMonth(
          index: kPagerBaseline + delta,
          anchorYear: 2026,
          anchorMonth: 4,
        );
        expect(
          monthToPageIndex(
            year: m.year,
            month: m.month,
            anchorYear: 2026,
            anchorMonth: 4,
          ),
          kPagerBaseline + delta,
          reason: 'delta=$delta',
        );
      }
    });
  });
}
```

- [ ] **Step 2: 테스트 실행해 실패 확인**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter test test/features/calendar/presentation/page_index_mapping_test.dart`

Expected: FAIL — 모듈 파일/심볼 없음

- [ ] **Step 3: 모듈 구현**

```dart
// lib/features/calendar/presentation/widgets/page_index_mapping.dart

/// PageView 가상 인덱스의 baseline. 이 인덱스가 anchor 월에 대응.
/// ±100년 (±1200개월) 범위를 충분히 커버.
const int kPagerBaseline = 1200;

/// 페이지 인덱스 → (year, month) 1일 기준 DateTime.
/// anchor는 페이저가 생성된 시점의 기준 월.
DateTime pageIndexToMonth({
  required int index,
  required int anchorYear,
  required int anchorMonth,
}) {
  final delta = index - kPagerBaseline;
  return DateTime(anchorYear, anchorMonth + delta, 1);
}

/// (year, month) → 페이지 인덱스.
/// DateTime 산술 보정이 필요 없도록 직접 12개월 단위 계산.
int monthToPageIndex({
  required int year,
  required int month,
  required int anchorYear,
  required int anchorMonth,
}) {
  return kPagerBaseline + (year - anchorYear) * 12 + (month - anchorMonth);
}
```

- [ ] **Step 4: 테스트 실행해 통과 확인**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter test test/features/calendar/presentation/page_index_mapping_test.dart`

Expected: PASS — 모든 테스트 통과

- [ ] **Step 5: 커밋**

```bash
git add lib/features/calendar/presentation/widgets/page_index_mapping.dart test/features/calendar/presentation/page_index_mapping_test.dart
git commit -m "$(cat <<'EOF'
feat(calendar): 페이지 인덱스 ↔ 월 매핑 모듈 추가

CalendarMonthPager가 사용할 anchor 주입형 매핑 함수 + 단위 테스트.
baseline 1200으로 ±100년 범위 커버.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: monthEventsByYearMonthProvider family 추가

**Files:**
- Modify: `lib/features/calendar/presentation/providers/calendar_providers.dart`

페이지마다 자기 월의 이벤트를 받기 위한 family. CRUD 시점에 family도 함께 invalidate.

- [ ] **Step 1: family provider 추가**

`calendar_providers.dart`의 `selectedMonthEventsProvider` 정의(라인 19~22) 바로 뒤에 추가:

```dart
/// (year, month) → 그 월의 이벤트 (PageView 페이지마다 사용).
/// selectedMonthEventsProvider와 별도 캐시이므로 CRUD 시 둘 다 invalidate.
final monthEventsByYearMonthProvider = FutureProvider.family<
    List<CalendarEvent>, ({int year, int month})>((ref, key) async {
  final repository = ref.watch(calendarRepositoryProvider);
  return repository.getEventsByMonth(key.year, key.month);
});
```

- [ ] **Step 2: SelectedMonthEventsNotifier의 CRUD 4곳에 family invalidate 추가**

기존 `addEvent`, `updateEvent`, `deleteEvent`, `toggleCompleted` 4개 메서드의 `ref.invalidateSelf()` 직전에 family invalidate 한 줄 추가. 변경 전(예시 `addEvent`):

```dart
  Future<void> addEvent(CalendarEvent event) async {
    final repository = ref.read(calendarRepositoryProvider);
    await repository.createEvent(event);
    ref.invalidateSelf();
    await _syncNotifications();
  }
```

변경 후:

```dart
  Future<void> addEvent(CalendarEvent event) async {
    final repository = ref.read(calendarRepositoryProvider);
    await repository.createEvent(event);
    ref.invalidate(monthEventsByYearMonthProvider);
    ref.invalidateSelf();
    await _syncNotifications();
  }
```

같은 패턴을 `updateEvent`, `deleteEvent`, `toggleCompleted`에 적용 (4개 메서드 모두 `ref.invalidateSelf()` 직전).

- [ ] **Step 3: analyze 실행**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter analyze lib/features/calendar/`

Expected: PASS, `No issues found!`

- [ ] **Step 4: 기존 테스트 회귀 확인**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter test test/features/calendar/`

Expected: PASS — 기존 캘린더 테스트 통과

- [ ] **Step 5: 커밋**

```bash
git add lib/features/calendar/presentation/providers/calendar_providers.dart
git commit -m "$(cat <<'EOF'
feat(calendar): monthEventsByYearMonthProvider family 추가

페이지뷰가 페이지마다 자기 월 이벤트를 받기 위한 캐시.
SelectedMonthEventsNotifier의 CRUD에서 함께 invalidate.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: 외부 invalidate 호출처에 family 추가

**Files:**
- Modify: `lib/features/schedule/presentation/providers/schedule_providers.dart` (3곳)
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (1곳)
- Modify: `lib/features/trash/presentation/providers/trash_providers.dart` (1곳)
- Modify: `lib/features/import/presentation/providers/import_providers.dart` (1곳)
- Modify: `lib/features/calendar/presentation/screens/calendar_screen.dart` (1곳)

다른 화면/플로우에서 캘린더 이벤트가 변경될 때 family 캐시도 stale → 함께 invalidate.

- [ ] **Step 1: schedule_providers.dart 3곳 수정**

기존 `ref.invalidate(selectedMonthEventsProvider);` 라인 3곳(56, 107, 116) 각각의 직전에 family invalidate 한 줄 추가.

라인 56 변경 전:
```dart
      ref.invalidate(selectedMonthEventsProvider);
```
변경 후:
```dart
      ref.invalidate(monthEventsByYearMonthProvider);
      ref.invalidate(selectedMonthEventsProvider);
```

라인 107, 116도 같은 형태로 한 줄씩 위에 추가.

또한 파일 상단 import에 `monthEventsByYearMonthProvider` 사용을 위해 기존 calendar_providers.dart import가 이미 있으면 그대로(같은 파일에서 export됨). 없으면 추가:

```dart
import '../../../calendar/presentation/providers/calendar_providers.dart';
```

(이 import는 이미 존재함 — `selectedMonthEventsProvider`/`calendarRepositoryProvider` 사용 중)

- [ ] **Step 2: settings_providers.dart 라인 49 수정**

변경 전:
```dart
      _ref.invalidate(selectedMonthEventsProvider);
```
변경 후:
```dart
      _ref.invalidate(monthEventsByYearMonthProvider);
      _ref.invalidate(selectedMonthEventsProvider);
```

- [ ] **Step 3: trash_providers.dart 라인 53 수정**

변경 전:
```dart
    ref.invalidate(selectedMonthEventsProvider);
```
변경 후:
```dart
    ref.invalidate(monthEventsByYearMonthProvider);
    ref.invalidate(selectedMonthEventsProvider);
```

- [ ] **Step 4: import_providers.dart 라인 173 수정**

변경 전:
```dart
    _ref.invalidate(selectedMonthEventsProvider);
```
변경 후:
```dart
    _ref.invalidate(monthEventsByYearMonthProvider);
    _ref.invalidate(selectedMonthEventsProvider);
```

- [ ] **Step 5: calendar_screen.dart 라인 306 수정**

(이건 Task 5에서 calendar_screen 통째로 손볼 때 함께 처리해도 되지만, 변경면 분리를 위해 여기서 처리.)

변경 전:
```dart
        ref.invalidate(selectedMonthEventsProvider);
```
변경 후:
```dart
        ref.invalidate(monthEventsByYearMonthProvider);
        ref.invalidate(selectedMonthEventsProvider);
```

- [ ] **Step 6: analyze + 회귀 테스트**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter analyze && flutter test`

Expected: PASS, 모든 단위 테스트 + 신규 매핑 테스트 통과

- [ ] **Step 7: 커밋**

```bash
git add lib/features/schedule/presentation/providers/schedule_providers.dart lib/features/settings/presentation/providers/settings_providers.dart lib/features/trash/presentation/providers/trash_providers.dart lib/features/import/presentation/providers/import_providers.dart lib/features/calendar/presentation/screens/calendar_screen.dart
git commit -m "$(cat <<'EOF'
chore(calendar): 외부 invalidate 7곳에 family 함께 추가

settings/schedule/trash/import/calendar 화면에서 캘린더 이벤트가
변경될 때 monthEventsByYearMonthProvider 캐시도 함께 무효화.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: CalendarMonthPager 신규 위젯

**Files:**
- Create: `lib/features/calendar/presentation/widgets/calendar_month_pager.dart`

PageView 래퍼. `ConsumerStatefulWidget`으로 구현해 `PageController`와 `ref.listenManual` 사용.

- [ ] **Step 1: 위젯 구현**

```dart
// lib/features/calendar/presentation/widgets/calendar_month_pager.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../providers/calendar_providers.dart';
import 'calendar_grid.dart';
import 'page_index_mapping.dart';

/// 월 단위 가로 슬라이딩 페이저. 기존 GestureDetector(onHorizontalDragEnd)를 대체.
///
/// - 페이지 인덱스 ↔ (year, month) 매핑은 [pageIndexToMonth] / [monthToPageIndex] 사용
/// - 외부에서 [selectedDateProvider]가 바뀌면 [PageController.animateToPage]로 따라감
/// - 페이지가 슬라이드 완료되면 [selectedDateProvider]를 새 월로 갱신
class CalendarMonthPager extends ConsumerStatefulWidget {
  const CalendarMonthPager({
    super.key,
    required this.onDateSelected,
  });

  /// 그리드 내 날짜 셀 탭 콜백 (calendar_screen에서 selectedDate 갱신용).
  final void Function(DateTime date) onDateSelected;

  @override
  ConsumerState<CalendarMonthPager> createState() =>
      _CalendarMonthPagerState();
}

class _CalendarMonthPagerState extends ConsumerState<CalendarMonthPager> {
  late final int _anchorYear;
  late final int _anchorMonth;
  late final PageController _controller;
  ProviderSubscription<DateTime>? _selectedDateSub;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(selectedDateProvider);
    _anchorYear = initial.year;
    _anchorMonth = initial.month;
    _controller = PageController(initialPage: kPagerBaseline);

    // 외부에서 selectedDate가 바뀌면 (chevron / "오늘로 점프" / 일정 확정 등)
    // PageView를 그 페이지로 animateToPage. 무한 루프 방지를 위해
    // 현재 페이지와 다를 때만 명령.
    _selectedDateSub = ref.listenManual<DateTime>(
      selectedDateProvider,
      (prev, next) {
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
      },
    );
  }

  @override
  void dispose() {
    _selectedDateSub?.close();
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    final newMonth = pageIndexToMonth(
      index: index,
      anchorYear: _anchorYear,
      anchorMonth: _anchorMonth,
    );
    final current = ref.read(selectedDateProvider);
    if (current.year != newMonth.year || current.month != newMonth.month) {
      ref.read(selectedDateProvider.notifier).state = newMonth;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // 그리드 영역 고정 높이 (calendar_grid가 자체 비율을 가지지만,
      // PageView는 자식 높이를 자동으로 맞추지 않으므로 명시).
      height: 320,
      child: PageView.builder(
        controller: _controller,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final m = pageIndexToMonth(
            index: index,
            anchorYear: _anchorYear,
            anchorMonth: _anchorMonth,
          );
          return _CalendarPage(
            year: m.year,
            month: m.month,
            onDateSelected: widget.onDateSelected,
          );
        },
      ),
    );
  }
}

/// 단일 월 페이지 — 자기 (year, month)로 family를 watch해 그리드 그림.
class _CalendarPage extends ConsumerWidget {
  const _CalendarPage({
    required this.year,
    required this.month,
    required this.onDateSelected,
  });

  final int year;
  final int month;
  final void Function(DateTime date) onDateSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(
      monthEventsByYearMonthProvider((year: year, month: month)),
    );
    final selectedDate = ref.watch(selectedDateProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing16),
      child: eventsAsync.when(
        data: (events) {
          final eventsMap = <String, List>{};
          for (final e in events) {
            eventsMap.putIfAbsent(e.eventDate, () => []).add(e);
          }
          return CalendarGrid(
            year: year,
            month: month,
            selectedDate: selectedDate,
            eventsMap: eventsMap.cast(),
            onDateSelected: onDateSelected,
          );
        },
        loading: () => const SizedBox(
          height: 280,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => const SizedBox(
          height: 280,
          child: Center(
            child: Text(AppStrings.error, style: TextStyle(color: AppColors.error)),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: analyze**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter analyze lib/features/calendar/`

Expected: PASS

- [ ] **Step 3: 커밋**

```bash
git add lib/features/calendar/presentation/widgets/calendar_month_pager.dart
git commit -m "$(cat <<'EOF'
feat(calendar): CalendarMonthPager 신규 위젯

PageView.builder + PageController로 월 단위 가로 슬라이드.
ref.listenManual(selectedDateProvider)로 외부 트리거 동기화,
현재 페이지 비교로 무한 루프 방지.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: calendar_screen 통합 — 기존 GestureDetector 제거 + Pager 삽입 + "오늘" 텍스트 제거

**Files:**
- Modify: `lib/features/calendar/presentation/screens/calendar_screen.dart`

- [ ] **Step 1: import 추가**

`calendar_screen.dart` 상단 import 블록에 추가:

```dart
import '../widgets/calendar_month_pager.dart';
```

- [ ] **Step 2: GestureDetector + 그리드 영역 통째로 CalendarMonthPager로 교체**

라인 47~82 (`GestureDetector(onHorizontalDragEnd: ...)`부터 끝나는 `),`까지) 통째로 다음으로 교체:

```dart
          CalendarMonthPager(
            onDateSelected: (date) {
              ref.read(selectedDateProvider.notifier).state = date;
            },
          ),
```

- [ ] **Step 3: 헤더의 "오늘" Text 위젯 + Column 단순화**

기존 코드(라인 177~202):

```dart
          GestureDetector(
            onTap: () {
              final today = DateTime.now();
              ref.read(selectedDateProvider.notifier).state = today;
            },
            child: Column(
              children: [
                Text(
                  _monthFormatter.format(selectedDate),
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  CalendarStrings.today,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.0,
                    color: AppColors.goldMuted,
                  ),
                ),
              ],
            ),
          ),
```

다음으로 교체 (Column 제거 + "오늘" 위젯 제거 + 탭 액션 유지):

```dart
          GestureDetector(
            onTap: () {
              final today = DateTime.now();
              ref.read(selectedDateProvider.notifier).state = today;
            },
            child: Text(
              _monthFormatter.format(selectedDate),
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: AppColors.ink,
              ),
            ),
          ),
```

- [ ] **Step 4: monthEventsMap watch 제거 (이제 페이지 내부에서 처리)**

calendar_screen.dart 상단(라인 30~31)의:

```dart
    final monthEventsMap = ref.watch(monthEventsMapProvider);
```

이 라인을 삭제. `monthEventsMap` 변수는 Step 2에서 GestureDetector를 통째로 교체했기 때문에 더 이상 사용되지 않음.

(`monthEventsGroupedProvider`는 이벤트 리스트 영역에서 계속 사용되므로 그대로 유지.)

- [ ] **Step 5: analyze + 전체 테스트**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter analyze && flutter test`

Expected: PASS, 모든 테스트 통과, 사용하지 않는 변수 경고 없음

- [ ] **Step 6: 커밋**

```bash
git add lib/features/calendar/presentation/screens/calendar_screen.dart
git commit -m "$(cat <<'EOF'
feat(calendar): 월 슬라이드 도입 + "오늘" 텍스트 제거

기존 onHorizontalDragEnd 점프를 CalendarMonthPager 슬라이딩으로 교체.
헤더 가운데 "오늘" 라벨 텍스트만 제거(탭으로 오늘 점프하는 액션은 유지).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: CalendarStrings.today 상수 제거

**Files:**
- Modify: `lib/core/constants/strings/calendar_strings.dart`

Task 5에서 마지막 사용처가 사라졌으므로 안전하게 제거.

- [ ] **Step 1: 상수 제거 + 사용처 재확인**

Run 사용처 재확인:
```bash
cd /Users/kwangsukim/i_code/planroutine && grep -rn "CalendarStrings\.today\b" lib test
```

Expected: 결과 없음 (Task 5 완료 후)

`calendar_strings.dart`에서 `today` 상수 라인 한 줄 삭제. 정확한 위치는 파일을 열어 확인 후 그 한 줄 삭제.

- [ ] **Step 2: analyze + 전체 테스트**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter analyze && flutter test`

Expected: PASS

- [ ] **Step 3: 커밋**

```bash
git add lib/core/constants/strings/calendar_strings.dart
git commit -m "$(cat <<'EOF'
chore(calendar): 미사용 CalendarStrings.today 상수 제거

월 슬라이드 도입과 함께 "오늘" 텍스트가 화면에서 사라져
참조하는 코드가 더 이상 없음.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: 회귀 테스트 + analyze

**Files:** 변경 없음

- [ ] **Step 1: 단위 테스트 전체 실행**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter test`

Expected: PASS — 120개 + 신규 매핑 테스트(약 9개) 통과

- [ ] **Step 2: analyze**

Run: `cd /Users/kwangsukim/i_code/planroutine && flutter analyze`

Expected: `No issues found!`

통합 테스트는 스킵(시뮬레이터 빌드 후 release IPA 91169 충돌 우려 + 본 작업은 단위 테스트로 회귀 충분히 잡힘 + TestFlight 내부 테스트로 시각적 검증).

---

### Task 8: TestFlight 배포

**Files:** 변경 없음

CLAUDE.md의 **배포 플로우 정책** 및 deploy_flow 메모리에 따라 analyze + test 통과 시 사용자 승인 없이 진행.

- [ ] **Step 1: TestFlight 배포**

Run: `cd /Users/kwangsukim/i_code/planroutine && ./ios/bin/fastlane.sh beta`

Expected: build_number 자동 +1, IPA 빌드, TestFlight 업로드 성공

배포 실패 시 멈추고 사용자에 보고.

- [ ] **Step 2: 원격 push**

Run: `git push origin main`

Expected: origin/main에 본 작업의 커밋들 반영

---

## Self-Review

### Spec coverage

| Spec 요건 | 구현 Task |
|-----------|-----------|
| 그리드만 슬라이드 (A안) | Task 4 + Task 5 |
| PageView.builder 기반 | Task 4 |
| 페이지 인덱스 ↔ 월 매핑 (anchor 주입) | Task 1 |
| `monthEventsByYearMonthProvider` family 신규 | Task 2 |
| `selectedMonthEventsProvider`는 그대로 유지 | Task 2 (CRUD에 family invalidate만 추가) |
| `ref.listenManual` + 현재 페이지 비교 무한 루프 방지 | Task 4 |
| chevron / 오늘로 점프 / 외부 invalidate 동기화 | Task 4 (listen) + Task 3 (외부 7곳 family invalidate) |
| 트랜지션 곡선 280ms easeOutCubic | Task 4 |
| `GestureDetector(onHorizontalDragEnd)` 제거 | Task 5 Step 2 |
| 헤더 "오늘" Text 제거 (탭 액션 유지) | Task 5 Step 3 |
| `CalendarStrings.today` 상수 제거 | Task 6 |
| 매핑 단위 테스트 | Task 1 |
| 회귀 + analyze | Task 7 |

모든 spec 요건이 Task에 매핑됨. 빈 항목 없음.

### Placeholder scan

전체 plan에 "TBD", "TODO", "implement later" 없음. 모든 코드 step에 실제 코드. 모든 명령에 expected 결과 명시.

### Type consistency

- `pageIndexToMonth` (Task 1) → `_CalendarMonthPagerState` 및 `_CalendarPage` (Task 4)에서 동일 시그니처(named arg `index/anchorYear/anchorMonth`)로 호출.
- `monthToPageIndex` (Task 1) → `_CalendarMonthPagerState.initState` 및 `_selectedDateSub` 콜백 (Task 4)에서 동일 시그니처.
- `monthEventsByYearMonthProvider` (Task 2) family key는 `({int year, int month})` records 타입 → Task 4의 `_CalendarPage.build`와 Task 3의 invalidate 호출(전체 family invalidate라 key 무관)에서 일관.
- `CalendarMonthPager.onDateSelected` (Task 4) `void Function(DateTime)` → Task 5 Step 2에서 `(date) { ref.read(selectedDateProvider.notifier).state = date; }`로 호출, 시그니처 일치.

타입/시그니처 충돌 없음.
