# 제목 연도 +1 이동 + 가져온 자료 `작년` 배지 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 캘린더 목록에 "가져온 자료"임을 알리는 `작년` 배지를 달고, 제목 연도 바꾸기를 "올해로 맞추기"에서 "한 해 밀기(+1년)"로 바꿔 편집 화면 전용으로 옮긴다.

**Architecture:** 조르는 쪽(목록 배지)과 고치는 쪽(편집 칩)의 기준을 분리한다. 목록 배지는 출처(`schedules.source_id`)만 보고 연도를 아예 보지 않아 반복될 여지가 없고, 편집 칩은 사용자가 일부러 연 화면에만 있어 몇 번 눌리든 무해하다. 출처는 스키마를 늘리지 않고 조회 시점 LEFT JOIN으로 가져온다.

**Tech Stack:** Flutter 3.x / Dart, Riverpod, Freezed(`CalendarEvent`), sqflite, flutter_test

**설계 스펙:** `docs/superpowers/specs/2026-07-26-title-year-shift-and-import-badge-design.md`

## Global Constraints

- 상태 관리는 **Riverpod만** 사용한다. 다른 라이브러리 금지.
- **`lib/` 안에서는 `!` 강제 언래핑 금지.** nullable은 지역 변수로 받아 null 체크 후 사용한다.
  (테스트 코드는 예외 — 이 리포 기존 테스트가 `result!.foo` 형태를 일관되게 쓴다.)
- 하드코딩 금지: 색은 `AppColors`, 크기는 `AppSizes`, 문자열은 `AppStrings` / 도메인별 `*Strings` 클래스.
- 파일명 snake_case, 클래스명 PascalCase, **한글 UI + 한글 주석**.
- **기존 테스트 삭제 금지.** 동작이 바뀌어 깨지는 테스트는 새 동작에 맞게 **수정**한다.
- **골드(`AppColors.gold` / `goldFill`)는 오늘·중요 강조 전용.** 이번에 추가되는 배지에 쓰지 않는다.
- `_buildEvent()`의 편집 분기는 `existing.copyWith(...)`를 유지한다 — 적지 않은 필드가 보존되는 것이 계약이다.
- **이 문서의 행 번호는 작업 시작 시점 원본 기준 참고값**이다. 앞 Task가 같은 파일을 고치면
  번호가 밀리므로, 위치는 항상 **인용된 코드 블록과 심볼 이름으로** 찾는다.
- 각 Task 끝에 `flutter analyze`(경고 0) + `flutter test`(전부 통과)를 확인하고 커밋한다.

## File Structure

| 파일 | 책임 | Task |
|---|---|---|
| `lib/features/calendar/domain/calendar_event.dart` | `fromImport` 읽기 전용 파생 필드 추가 (`toMap`엔 넣지 않음) | 1 |
| `lib/features/calendar/data/calendar_repository.dart` | `getEventsByDateRange`를 LEFT JOIN rawQuery로 | 1 |
| `lib/core/constants/strings/calendar_strings.dart` | `fromImportBadge`(작년) · `yearShiftAll` 문자열 | 2·3 |
| `lib/features/calendar/presentation/widgets/event_list_section.dart` | 골드 연도 배지·`_goldPill` 제거, `작년` 배지 추가 | 2 |
| `lib/features/calendar/presentation/widgets/month_event_list.dart` | `onEventBumpYear` 파라미터 제거 | 2 |
| `lib/features/calendar/presentation/screens/calendar_screen.dart` | `_onBumpYear` 핸들러·배선 제거 | 2 |
| `lib/core/utils/title_year_utils.dart` | `bumpTitleYear` → `shiftTitleYears`(상대 이동) | 3 |
| `lib/features/calendar/presentation/widgets/event_edit_dialog.dart` | 연도 칩을 +1년 규칙으로 | 3 |

**Task 의존 관계:** 1 → 2. Task 2가 `bumpTitleYear`의 마지막 사용처 하나(편집 칩)만 남기므로, Task 3에서 함수 교체와 칩 교체를 한 번에 해야 컴파일이 깨지지 않는다.

---

### Task 1: `fromImport` 파생 필드 + 조회 조인

캘린더 이벤트가 "에듀파인 CSV에서 온 것인지"를 조회 시점에 알 수 있게 한다. UI는 아직 건드리지 않는다.

**Files:**
- Modify: `lib/features/calendar/domain/calendar_event.dart` (생성자 필드, `fromMap`)
- Modify: `lib/features/calendar/data/calendar_repository.dart` (`getEventsByDateRange`)
- Test: `test/features/calendar/data/calendar_repository_test.dart` (그룹 추가)

**Interfaces:**
- Consumes: `DatabaseHelper.tableCalendarEvents` · `DatabaseHelper.tableSchedules` 상수, `formatDate(DateTime)`
- Produces: `CalendarEvent.fromImport` (`bool`, 기본 `false`) — Task 2가 이 값으로 배지를 그린다

- [ ] **Step 1: 실패하는 테스트 작성**

`test/features/calendar/data/calendar_repository_test.dart`의 `main()` 안, 기존 group들 아래에 추가한다.
(파일 상단 import에 `package:planroutine/core/database/database_helper.dart`가 이미 있다.)

```dart
  group('fromImport — 가져온 자료 판별', () {
    /// schedules 행을 직접 넣는다. source_id가 있으면 에듀파인 CSV 출처다.
    Future<int> insertSchedule({int? sourceId}) async {
      final database = await db.database;
      return database.insert(DatabaseHelper.tableSchedules, {
        'title': '업무',
        'scheduled_date': '2026-05-01',
        'status': 'confirmed',
        'source_id': sourceId,
        'created_at': '2026-01-01T00:00:00.000',
        'updated_at': '2026-01-01T00:00:00.000',
      });
    }

    test('CSV 출처(schedule.source_id 있음) 이벤트는 fromImport=true', () async {
      final scheduleId = await insertSchedule(sourceId: 77);
      await repo.createEvent(buildEvent(title: '가져온 업무', scheduleId: scheduleId));

      final events = await repo.getEventsByDate(DateTime(2026, 5, 1));
      expect(events.single.fromImport, true);
    });

    test('확정 경로지만 CSV 출처가 아니면 fromImport=false', () async {
      final scheduleId = await insertSchedule();
      await repo.createEvent(buildEvent(title: '사진 AI 일정', scheduleId: scheduleId));

      final events = await repo.getEventsByDate(DateTime(2026, 5, 1));
      expect(events.single.fromImport, false);
    });

    test('손으로 넣은 이벤트(scheduleId 없음)는 fromImport=false', () async {
      await repo.createEvent(buildEvent(title: '손입력'));

      final events = await repo.getEventsByDate(DateTime(2026, 5, 1));
      expect(events.single.fromImport, false);
    });

    test('toMap에는 from_import가 없다 — 있으면 insert가 깨진다', () {
      const event = CalendarEvent(
        title: '아무거나',
        eventDate: '2026-05-01',
        fromImport: true,
      );
      expect(event.toMap().containsKey('from_import'), false);
    });
  });
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/calendar/data/calendar_repository_test.dart`
Expected: FAIL — `CalendarEvent`에 `fromImport` 이름 인자가 없어 컴파일 에러

- [ ] **Step 3: 모델에 파생 필드 추가**

`lib/features/calendar/domain/calendar_event.dart`의 생성자에서 `kind` 바로 아래에 추가:

```dart
    @Default(EntryKind.task) EntryKind kind,
    /// 에듀파인 CSV로 가져온 자료인지. **조회 시점 조인으로 채우는 파생 값**이라
    /// DB 컬럼이 아니다 — [toMap]에 넣으면 insert가 깨진다.
    @JsonKey(includeToJson: false) @Default(false) bool fromImport,
```

같은 파일의 `fromMap`에서 `kind:` 다음 줄에 추가:

```dart
      kind: EntryKind.fromValue(map['kind'] as String?),
      fromImport: (map['from_import'] as int?) == 1,
```

`toMap()`은 **건드리지 않는다.** 손으로 쓴 메서드라 지금 그대로면 `from_import`가 들어가지 않는다.
`@JsonKey(includeToJson: false)`는 생성되는 `toJson()`(외부 내보내기용) 쪽을 막는 것이라
목적이 다르다 — 쓰고 있는 json_serializable 버전이 이 인자를 모른다고 하면 애너테이션만 빼고
`@Default(false) bool fromImport,`로 두면 된다. **가드의 본체는 `toMap()`에 넣지 않는 것**이다.

Freezed 코드 재생성:

```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 4: 조회에 LEFT JOIN 적용**

`calendar_repository.dart`의 `getEventsByDateRange` 본문을 통째로 교체한다:

```dart
  /// 날짜 범위 이벤트 조회 (삭제되지 않은 것만).
  ///
  /// `from_import`는 컬럼이 아니라 조인으로 만드는 파생 값이다 — 출처의 진실은
  /// `schedules.source_id` 한 곳에만 두고, calendar_events에 복제하지 않는다.
  Future<List<CalendarEvent>> getEventsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _dbHelper.database;
    final startStr = formatDate(start);
    final endStr = formatDate(end);
    final results = await db.rawQuery(
      '''
      SELECT e.*, (s.source_id IS NOT NULL) AS from_import
      FROM ${DatabaseHelper.tableCalendarEvents} e
      LEFT JOIN ${DatabaseHelper.tableSchedules} s ON s.id = e.schedule_id
      WHERE e.event_date >= ? AND e.event_date <= ? AND e.deleted_at IS NULL
      ORDER BY e.event_date ASC, e.created_at ASC
      ''',
      [startStr, endStr],
    );
    return results.map(CalendarEvent.fromMap).toList();
  }
```

- [ ] **Step 5: 통과 확인**

Run: `flutter test test/features/calendar/data/calendar_repository_test.dart`
Expected: PASS (기존 테스트 + 신규 4건)

- [ ] **Step 6: 회귀 확인**

Run: `flutter analyze && flutter test`
Expected: analyze 경고 0 / 전체 통과. 오늘 탭도 `getEventsByDateRange`를 쓰므로 `today` 테스트가 깨지면 안 된다.

- [ ] **Step 7: 커밋**

```bash
git add lib/features/calendar/domain/calendar_event.dart \
        lib/features/calendar/domain/calendar_event.freezed.dart \
        lib/features/calendar/domain/calendar_event.g.dart \
        lib/features/calendar/data/calendar_repository.dart \
        test/features/calendar/data/calendar_repository_test.dart
git commit -m "feat(calendar): 조회 조인으로 가져온 자료 여부(fromImport) 제공"
```

---

### Task 2: 목록 배지 교체 — 골드 연도 배지 → `작년` 출처 배지

연도 바꾸기가 편집 전용이 되므로 목록의 골드 연도 배지를 없애고, 그 자리에 출처를 알리는 조용한 `작년` 배지를 둔다.

**Files:**
- Modify: `lib/core/constants/strings/calendar_strings.dart` (`fromImportBadge` 추가)
- Modify: `lib/features/calendar/presentation/widgets/event_list_section.dart` (`onEventBumpYear` 필드, `_buildYearBadge`, `_goldPill` 제거 / `_buildImportBadge` 추가)
- Modify: `lib/features/calendar/presentation/widgets/month_event_list.dart` (`onEventBumpYear` 파라미터 제거)
- Modify: `lib/features/calendar/presentation/screens/calendar_screen.dart` (`_onBumpYear`·배선·`title_year_utils` import 제거)
- Rename + Modify: `test/features/calendar/event_list_year_badge_test.dart` → `test/features/calendar/event_list_import_badge_test.dart`

**Interfaces:**
- Consumes: Task 1의 `CalendarEvent.fromImport`
- Produces: `EventListSection`/`MonthEventList`에서 `onEventBumpYear` 파라미터가 **사라진다** — 이후 호출부는 넘기면 안 된다

- [ ] **Step 1: 테스트 파일 이름 바꾸기**

```bash
git mv test/features/calendar/event_list_year_badge_test.dart \
       test/features/calendar/event_list_import_badge_test.dart
```

- [ ] **Step 2: 실패하는 테스트로 개정**

`test/features/calendar/event_list_import_badge_test.dart`를 아래 내용으로 **전체 교체**한다.
(기존 `캘린더 리스트 — 색상 통일` 그룹은 그대로 살리고, 연도 배지 그룹만 출처 배지 그룹으로 바꾼다.
`onEventBumpYear` 인자가 모든 호출에서 빠진 점에 주의.)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/features/calendar/presentation/widgets/event_list_section.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR', null);
  });

  final currentYear = DateTime.now().year;
  final oldYear = currentYear - 1;

  Future<void> pumpEvents(WidgetTester tester, List<CalendarEvent> events) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EventListSection(
              selectedDate: DateTime(currentYear, 1, 3),
              events: events,
              onEventTap: (_) {},
              onEventSaveToGoogle: null,
              onEventToggleCompleted: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('캘린더 리스트 — 색상 통일', () {
    testWidgets('저장된 색과 무관하게 막대는 기본 액센트색으로 렌더', (tester) async {
      await pumpEvents(tester, [
        CalendarEvent(
          id: 3,
          title: '행사 계획',
          eventDate: '$currentYear-01-03',
          color: '#EF4444', // 빨강이 저장돼 있어도 렌더는 기본색이어야 함
        ),
      ]);

      final bar = tester.widget<Container>(
        find.byKey(const Key('event_accent_bar_3')),
      );
      final deco = bar.decoration as BoxDecoration;
      expect(deco.color, AppColors.eventAccent);
    });
  });

  group('캘린더 리스트 — 가져온 자료 배지', () {
    testWidgets('가져온 자료면 작년 배지가 보인다', (tester) async {
      await pumpEvents(tester, [
        CalendarEvent(
          id: 1,
          title: '$oldYear학년도 1차 학급편성 결과 제출',
          eventDate: '$currentYear-01-03',
          fromImport: true,
        ),
      ]);

      expect(find.byKey(const Key('event_import_badge_1')), findsOneWidget);
      expect(find.text('작년'), findsOneWidget);
    });

    testWidgets('제목에 연도가 없어도 가져온 자료면 배지가 붙는다', (tester) async {
      await pumpEvents(tester, [
        CalendarEvent(
          id: 2,
          title: '졸업식 학사일정 변경 안내',
          eventDate: '$currentYear-01-03',
          fromImport: true,
        ),
      ]);

      expect(find.byKey(const Key('event_import_badge_2')), findsOneWidget);
    });

    testWidgets('손으로 넣은 항목은 옛 연도가 있어도 배지가 없다', (tester) async {
      await pumpEvents(tester, [
        CalendarEvent(
          id: 3,
          title: '$oldYear학년도 겨울방학 계획',
          eventDate: '$currentYear-01-03',
        ),
      ]);

      expect(find.byKey(const Key('event_import_badge_3')), findsNothing);
      expect(find.text('작년'), findsNothing);
    });
  });

  group('캘린더 리스트 — 골드 연도 배지 제거', () {
    testWidgets('옛 연도가 있어도 연도 바꾸기 배지는 더 이상 없다', (tester) async {
      await pumpEvents(tester, [
        CalendarEvent(
          id: 4,
          title: '$oldYear학년도 겨울방학 계획',
          eventDate: '$currentYear-01-03',
          fromImport: true,
        ),
      ]);

      expect(find.byKey(const Key('year_bump_badge_4')), findsNothing);
      expect(find.textContaining('→'), findsNothing);
    });
  });
}
```

- [ ] **Step 3: 실패 확인**

Run: `flutter test test/features/calendar/event_list_import_badge_test.dart`
Expected: FAIL — `EventListSection`에 아직 `onEventBumpYear`가 required라 컴파일 에러

- [ ] **Step 4: 문자열 추가**

`lib/core/constants/strings/calendar_strings.dart`의 `// 중요 표시` 섹션 **위**에 추가:

```dart
  // 가져온 자료 출처
  static const fromImportBadge = '작년';
```

- [ ] **Step 5: 목록 위젯 교체**

`event_list_section.dart`에서 순서대로:

(a) 상단 `import '../../../../core/utils/title_year_utils.dart';` **삭제**

(b) 생성자의 `required this.onEventBumpYear,` 줄과, 필드 선언

```dart
  /// 제목에 이전 연도가 있는 이벤트의 "연도 올해로" 배지 탭 콜백.
  final ValueChanged<CalendarEvent> onEventBumpYear;
```

를 주석 포함 **삭제**

(c) 행 조립부의 `_buildYearBadge(event),`를 다음으로 교체:

```dart
              _buildImportBadge(event),
```

(d) `_goldPill` 메서드 전체(주석 2줄 포함)와 `_buildYearBadge` 메서드 전체(주석 3줄 포함)를
**삭제**하고, 그 자리에 다음을 넣는다:

```dart
  /// 에듀파인 CSV로 가져온 자료임을 알리는 출처 배지.
  ///
  /// 연도를 보지 않는다 — 제목에 연도가 없어도 붙는다. 누르는 것이 아니므로
  /// 조용해야 하고, 종류 배지(채움)와 한 행에서 구분되도록 **테두리형**으로 그린다.
  /// 골드는 오늘·중요 전용이라 쓰지 않는다.
  Widget _buildImportBadge(CalendarEvent event) {
    if (!event.fromImport) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: AppSizes.spacing8),
      child: Container(
        key: Key('event_import_badge_${event.id}'),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spacing8,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.sub.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        ),
        child: Text(
          CalendarStrings.fromImportBadge,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.sub,
          ),
        ),
      ),
    );
  }
```

- [ ] **Step 6: 상위 위젯·화면에서 콜백 제거**

`month_event_list.dart` — 생성자의 `required this.onEventBumpYear,` 줄, 필드 선언
`final ValueChanged<CalendarEvent> onEventBumpYear;`(주석 포함), 그리고
`EventListSection(...)` 호출의 `onEventBumpYear: widget.onEventBumpYear,` 줄을 모두 **삭제**한다.

`calendar_screen.dart` —
- `MonthEventList(...)` 호출의 다음 두 줄을 **삭제**:

```dart
                      onEventBumpYear: (event) =>
                          _onBumpYear(context, ref, event),
```

- `_onBumpYear` 메서드 전체를 주석(`/// "이전 연도 자료" 배지 탭 …`)까지 **삭제**
- 상단 `import '../../../../core/utils/title_year_utils.dart';` **삭제**

- [ ] **Step 7: 통과 확인**

Run: `flutter test test/features/calendar/event_list_import_badge_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 8: 회귀 확인**

**먼저** 다른 테스트 파일에서 `onEventBumpYear` 인자를 지운다. 파라미터가 사라졌으므로
남겨두면 컴파일이 안 된다. 대상은 정확히 5개 파일이고, **그 인자 줄만** 지운다
(다른 어서션·구조는 건드리지 말 것):

| 파일 | 지울 곳 |
|---|---|
| `test/features/calendar/event_list_kind_test.dart` | 1곳 |
| `test/features/calendar/event_list_important_test.dart` | 1곳 |
| `test/features/calendar/event_list_toggle_swipe_test.dart` | 2곳 |
| `test/features/calendar/month_event_list_small_viewport_test.dart` | 1곳 |
| `test/features/calendar/month_event_list_jump_test.dart` | 1곳 |

확인: `grep -rn "onEventBumpYear" lib test integration_test` → 결과 0건이어야 한다.

Run: `flutter analyze && flutter test`
Expected: analyze 경고 0 (`_goldPill`·`onEventBumpYear` 미사용 경고가 남으면 안 된다) / 전체 통과.

- [ ] **Step 9: 커밋**

```bash
git add -A lib/features/calendar lib/core/constants/strings/calendar_strings.dart \
           test/features/calendar
git commit -m "feat(calendar): 목록 골드 연도 배지를 작년 출처 배지로 교체"
```

---

### Task 3: `shiftTitleYears`(+1년) + 편집 칩

절대 기준("올해로 맞춘다")을 상대 기준("한 해 민다")으로 바꾸고, 편집 칩이 그 규칙을 쓰게 한다. Task 2가 다른 사용처를 모두 없앴으므로 함수 교체와 칩 교체를 한 번에 해야 컴파일이 유지된다.

**Files:**
- Modify: `lib/core/utils/title_year_utils.dart` (함수 교체)
- Modify: `lib/core/constants/strings/calendar_strings.dart` (`yearShiftAll` 추가)
- Modify: `lib/features/calendar/presentation/widgets/event_edit_dialog.dart` (`_buildYearBumpChip`)
- Test: `test/core/utils/title_year_utils_test.dart` (전면 개정)
- Test: `test/features/calendar/event_edit_dialog_year_test.dart` (개정)

**Interfaces:**
- Consumes: 없음 (순수 함수)
- Produces: `({String title, List<int> from}) shiftTitleYears(String title, {int by = 1})` — `from`은 **중복 제거된 등장 순서** 원본 연도 목록

- [ ] **Step 1: 순수 함수 테스트 전면 개정**

`test/core/utils/title_year_utils_test.dart`를 아래 내용으로 **전체 교체**한다.
(기존 12건의 의도를 +1 기준으로 옮긴 것이다 — 삭제가 아니라 개정.)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/utils/title_year_utils.dart';

void main() {
  group('shiftTitleYears — 제목의 연도를 한 해 민다', () {
    test('학년도 표기를 한 해 뒤로', () {
      final r = shiftTitleYears('2025학년도 겨울방학 운영 계획');
      expect(r.title, '2026학년도 겨울방학 운영 계획');
      expect(r.from, [2025]);
    });

    test('"년" 표기도 이동', () {
      final r = shiftTitleYears('2025년 겨울방학 현수막 품의');
      expect(r.title, '2026년 겨울방학 현수막 품의');
      expect(r.from, [2025]);
    });

    test('올해 연도도 민다 — 12월 업무가 가리키는 2월 졸업식은 한 해 뒤가 된다', () {
      final r = shiftTitleYears('2026 졸업식 행사 협의');
      expect(r.title, '2027 졸업식 행사 협의');
      expect(r.from, [2026]);
    });

    test('미래 연도도 민다 (상대 기준이라 예외를 두지 않는다)', () {
      final r = shiftTitleYears('2027 졸업식 행사 협의');
      expect(r.title, '2028 졸업식 행사 협의');
      expect(r.from, [2027]);
    });

    test('연도 없는 제목은 그대로, from은 빈 리스트', () {
      final r = shiftTitleYears('종업식 및 졸업식 안내장');
      expect(r.title, '종업식 및 졸업식 안내장');
      expect(r.from, isEmpty);
    });

    test('한 제목에 두 연도 — 간격이 유지된다', () {
      final r = shiftTitleYears('2025학년도 안건발의서[2026학년도 보결수업 규정 개정]');
      expect(
        r.title,
        '2026학년도 안건발의서[2027학년도 보결수업 규정 개정]',
        reason: '"올해로 맞추기"는 둘 다 2026으로 뭉갰다 — 상대 이동은 1년 간격을 지킨다',
      );
      expect(r.from, [2025, 2026]);
    });

    test('두 해 전 자료는 한 번에 올해가 되지 않는다 (한 번 더 눌러야 함)', () {
      final r = shiftTitleYears('2024학년도 결산 보고');
      expect(r.title, '2025학년도 결산 보고');
      expect(r.from, [2024]);
    });

    test('연도처럼 보이는 비연도 4자리는 건드리지 않음', () {
      final r = shiftTitleYears('1000명 참가 행사 계획');
      expect(r.title, '1000명 참가 행사 계획');
      expect(r.from, isEmpty);
    });

    test('더 긴 숫자열 안의 20xx는 연도로 보지 않음', () {
      final r = shiftTitleYears('문서120250 처리');
      expect(r.title, '문서120250 처리');
      expect(r.from, isEmpty);
    });

    test('맨 끝에 오는 연도도 이동', () {
      final r = shiftTitleYears('2024학년도 결산 2024');
      expect(r.title, '2025학년도 결산 2025');
      expect(r.from, [2024], reason: '같은 연도가 두 번 나와도 from은 중복 없이 1개');
    });

    test('한글에 바로 붙은 앞자리 연도도 이동 (앞이 숫자만 아니면 됨)', () {
      final r = shiftTitleYears('문서2025 처리');
      expect(r.title, '문서2026 처리');
      expect(r.from, [2025]);
    });

    test('세 연도 혼재 — 전부 한 해씩, from은 등장 순서', () {
      final r = shiftTitleYears('2023·2024 계획과 2027 전망');
      expect(r.title, '2024·2025 계획과 2028 전망');
      expect(r.from, [2023, 2024, 2027]);
    });

    test('by를 주면 그만큼 민다', () {
      final r = shiftTitleYears('2024학년도 결산 보고', by: 2);
      expect(r.title, '2026학년도 결산 보고');
      expect(r.from, [2024]);
    });
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/core/utils/title_year_utils_test.dart`
Expected: FAIL — `shiftTitleYears`가 정의되지 않아 컴파일 에러

- [ ] **Step 3: 순수 함수 교체**

`lib/core/utils/title_year_utils.dart` 전체를 다음으로 교체한다:

```dart
/// 제목 텍스트의 연도 이동 유틸리티.
///
/// 작년 CSV를 가져오면 날짜(scheduled_date)는 올해로 변환되지만 제목 문자열의
/// 연도("2025학년도 …")는 원본 그대로 남는다. 편집 시 이 연도를 한 해 미는 순수 함수.
///
/// **절대 기준이 아니라 상대 기준이다.** "올해로 맞추기"는 한 제목 안의 서로 다른
/// 연도를 같은 값으로 뭉갠다("2025학년도 안건[2026학년도 개정]" → 둘 다 2026).
/// 한 해씩 밀면 그 간격이 보존된다. 12월 업무 제목의 "2026 졸업식"이 두 달 뒤
/// 2월 졸업식을 가리키는 것처럼, 연도들의 관계는 지켜야 뜻이 남는다.
library;

/// 4자리 연도(20XX)만 매칭한다. 앞뒤가 숫자면 제외(문서번호 등 비연도 차단).
final RegExp _yearPattern = RegExp(r'(?<!\d)20\d\d(?!\d)');

/// [title]의 모든 연도를 [by]년만큼 민다.
///
/// 반환: 이동된 제목과, **중복을 제거한 등장 순서**의 원본 연도 목록([from]).
/// 연도가 없으면 [from]은 빈 리스트. 호출부는 [from]의 길이로 라벨을 고른다
/// (1개면 "2025 → 2026", 2개 이상이면 "연도 모두 +N년").
({String title, List<int> from}) shiftTitleYears(String title, {int by = 1}) {
  final from = <int>[];
  final newTitle = title.replaceAllMapped(_yearPattern, (match) {
    final year = int.parse(match.group(0) ?? '');
    if (!from.contains(year)) from.add(year);
    return (year + by).toString();
  });
  return (title: newTitle, from: from);
}
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/core/utils/title_year_utils_test.dart`
Expected: PASS (13 tests)

- [ ] **Step 5: 편집 칩 테스트 개정**

`test/features/calendar/event_edit_dialog_year_test.dart`의 `캘린더 이벤트 편집 — 연도 바꾸기 칩`
그룹 전체를 다음으로 교체한다. (`색상 피커 제거` 그룹과 파일 상단은 그대로 둔다.)

```dart
  group('캘린더 이벤트 편집 — 연도 바꾸기 칩', () {
    testWidgets('제목에 이전 연도를 입력하면 한 해 뒤로 미는 칩이 보인다', (tester) async {
      await pumpDialog(tester);
      await tester.enterText(titleField(), '$oldYear학년도 졸업식');
      await tester.pump();

      expect(find.text('$oldYear → $currentYear'), findsOneWidget);
    });

    testWidgets('올해 연도에도 칩이 보인다 — 내년으로 민다', (tester) async {
      await pumpDialog(tester);
      await tester.enterText(titleField(), '$currentYear 졸업식 행사 관련 협의');
      await tester.pump();

      expect(find.text('$currentYear → ${currentYear + 1}'), findsOneWidget);
    });

    testWidgets('연도가 없으면 칩이 없다', (tester) async {
      await pumpDialog(tester);
      await tester.enterText(titleField(), '졸업식 행사 협의');
      await tester.pump();

      expect(find.byKey(const Key('year_shift_chip')), findsNothing);
    });

    testWidgets('연도가 둘이면 개별 값 대신 "연도 모두" 문구를 쓴다', (tester) async {
      await pumpDialog(tester);
      await tester.enterText(titleField(), '$oldYear학년도 안건[$currentYear학년도 개정]');
      await tester.pump();

      expect(find.text('연도 모두 +1년'), findsOneWidget);
      expect(find.text('$oldYear → $currentYear'), findsNothing);
    });

    testWidgets('칩을 탭하면 제목의 모든 연도가 한 해씩 밀린다', (tester) async {
      await pumpDialog(tester);
      await tester.enterText(titleField(), '$oldYear학년도 안건[$currentYear학년도 개정]');
      await tester.pump();

      await tester.tap(find.byKey(const Key('year_shift_chip')));
      await tester.pump();

      expect(
        find.text('$currentYear학년도 안건[${currentYear + 1}학년도 개정]'),
        findsOneWidget,
      );
    });

    testWidgets('두 번 탭하면 두 해 밀린다', (tester) async {
      await pumpDialog(tester);
      await tester.enterText(titleField(), '$oldYear학년도 졸업식');
      await tester.pump();

      await tester.tap(find.byKey(const Key('year_shift_chip')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('year_shift_chip')));
      await tester.pump();

      expect(find.text('${currentYear + 1}학년도 졸업식'), findsOneWidget);
    });
  });
```

- [ ] **Step 6: 실패 확인**

Run: `flutter test test/features/calendar/event_edit_dialog_year_test.dart`
Expected: FAIL — `Key('year_shift_chip')`가 없고, 연도 2개일 때 `연도 모두 +1년`이 안 나온다

- [ ] **Step 7: 문자열 추가**

`lib/core/constants/strings/calendar_strings.dart`의 `// 가져온 자료 출처` 섹션 **아래**에 추가:

```dart
  // 연도 바꾸기 칩 (연도가 둘 이상일 때)
  static const yearShiftAll = '연도 모두 +1년';
```

- [ ] **Step 8: 편집 칩 교체**

`event_edit_dialog.dart`의 `_buildYearBumpChip` 메서드 전체를 주석까지 다음으로 교체한다.
`build()`의 호출부 이름도 `_buildYearShiftChip()`으로 함께 바꾼다.

```dart
  /// 제목에 연도가 있으면 나타나는 "연도 한 해 밀기" 원탭 칩.
  ///
  /// 컨트롤러를 구독해 입력 중에도 실시간으로 노출/숨김된다. 탭하면 제목의 **모든**
  /// 연도를 +1년 하고 커서를 끝으로 옮긴다. (저장은 사용자가 직접)
  ///
  /// 조건 없이 항상 뜬다 — 편집 화면은 사용자가 일부러 연 곳이라 조를 일이 없다.
  /// 목록 쪽에서 같은 조건을 쓰면 고칠 때마다 다시 조르는 순환이 된다.
  Widget _buildYearShiftChip() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _titleController,
      builder: (context, value, _) {
        final result = shiftTitleYears(value.text);
        if (result.from.isEmpty) return const SizedBox.shrink();
        final label = result.from.length == 1
            ? '${result.from.first} → ${result.from.first + 1}'
            : CalendarStrings.yearShiftAll;
        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: AppSizes.spacing8),
            child: ActionChip(
              key: const Key('year_shift_chip'),
              avatar: Icon(
                Icons.event_repeat,
                size: 18,
                color: AppColors.gold,
              ),
              label: Text(label),
              labelStyle: TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: AppColors.surfaceVariant,
              side: BorderSide(color: AppColors.gold),
              onPressed: () {
                _titleController.value = TextEditingValue(
                  text: result.title,
                  selection:
                      TextSelection.collapsed(offset: result.title.length),
                );
              },
            ),
          ),
        );
      },
    );
  }
```

- [ ] **Step 9: 통과 확인**

Run: `flutter test test/features/calendar/event_edit_dialog_year_test.dart`
Expected: PASS (7 tests — 연도 칩 6 + 색상 피커 1)

- [ ] **Step 10: 회귀 확인**

Run: `flutter analyze && flutter test`
Expected: analyze 경고 0 / 전체 통과. `bumpTitleYear`를 참조하는 곳이 남아 있으면 컴파일 에러가 난다 — 남았다면 Task 2에서 지웠어야 할 곳이니 보고할 것.

- [ ] **Step 11: 시뮬레이터로 실제 동작 확인**

Run: `flutter run -d "iPhone 17 Pro"` (또는 사용 가능한 시뮬레이터)
확인할 것:
1. 입력 탭에서 CSV를 가져와 확정 → 캘린더 목록 행에 `작년` 테두리 배지가 붙는다
2. 손으로 추가한 이벤트에는 배지가 없다
3. 목록에 골드 `2025→2026` 배지가 더 이상 없다
4. 행을 탭해 편집 → 제목이 `2026 졸업식 …`이면 칩이 `2026 → 2027`로 뜬다
5. 칩을 탭하면 제목이 바뀌고, 다시 탭하면 또 한 해 밀린다

- [ ] **Step 12: 커밋**

```bash
git add lib/core/utils/title_year_utils.dart \
        lib/core/constants/strings/calendar_strings.dart \
        lib/features/calendar/presentation/widgets/event_edit_dialog.dart \
        test/core/utils/title_year_utils_test.dart \
        test/features/calendar/event_edit_dialog_year_test.dart
git commit -m "feat(calendar): 제목 연도를 올해로 맞추기에서 한 해 밀기(+1년)로"
```

---

## 마무리

- [ ] **CLAUDE.md 갱신** — "제목 연도 바꾸기" 섹션을 새 규칙으로 다시 쓴다:
  - `bumpTitleYear`(절대) → `shiftTitleYears`(상대 +1년), `currentYear` 인자 없음
  - 노출 지점이 2곳 → **편집 칩 1곳**. 목록의 골드 연도 배지는 제거됨
  - 목록에는 대신 `작년` 출처 배지(`schedules.source_id` 기준, 조회 조인)
  - **조르는 쪽과 고치는 쪽의 기준을 분리한 이유**(`<`를 `<=`로 바꾸면 순환)
  - `CalendarEvent.fromImport`는 `toMap()`에 넣지 않는 파생 필드라는 것
- [ ] **릴리즈 노트** `docs/release_notes/1.2.0.ko.txt`에 사용자 언어로 2줄 추가
- [ ] **`document-release` 스킬로 옵시디언 작업 로그 작성**
- [ ] 배포는 사용자 판단에 따름
