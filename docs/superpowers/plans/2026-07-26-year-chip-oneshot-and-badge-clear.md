# 연도 칩 1회용 + `작년` 배지 저장 시 해제 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 편집 시트에서 저장하면 `작년` 배지와 연도 칩이 함께 영구히 꺼지고, 취소하면 되돌아가게 한다. 시트 안에서 연도 칩은 한 번만 눌린다.

**Architecture:** `calendar_events.reviewed_at`(DB v8) 하나가 배지와 칩을 함께 끈다. 저장이 유일한 기준이라 취소 시 원상복구가 별도 구현 없이 따라온다. 시트 안에서 두 번 누르는 것은 세션 상태(`_yearShifted`)가 막는다 — 수명이 다른 두 문제라 장치도 둘이다.

**Tech Stack:** Flutter 3.x / Dart, Riverpod, Freezed(`CalendarEvent`), sqflite, flutter_test

**설계 스펙:** `docs/superpowers/specs/2026-07-26-year-chip-oneshot-and-badge-clear-design.md`

## Global Constraints

- 상태 관리는 **Riverpod만** 사용한다. 다른 라이브러리 금지.
- **`lib/` 안에서는 `!` 강제 언래핑 금지.** nullable은 지역 변수로 받아 null 체크 후 사용한다.
  (테스트 코드는 예외 — 이 리포 기존 테스트가 `result!.foo` 형태를 일관되게 쓴다.)
- 하드코딩 금지: 색은 `AppColors`, 크기는 `AppSizes`, 문자열은 `AppStrings` / 도메인별 `*Strings` 클래스.
- 파일명 snake_case, 클래스명 PascalCase, **한글 UI + 한글 주석**.
- **기존 테스트 삭제 금지.** 동작이 바뀌어 깨지는 테스트는 새 동작에 맞게 **수정**한다.
- **`_buildEvent()`의 편집 분기는 `existing.copyWith(...)`를 유지한다.** `kind`·`googleEventId`·
  `deviceEventId`·`color`·`scheduleId`·`createdAt`·`completedAt`은 **적지 않는다** — 적지 않아야
  보존된다. 이번에 새로 명시하는 것은 `reviewedAt` 하나뿐이다.
- **`fromImport`는 파생 필드이므로 `toMap()`에 넣지 않는다**(기존 규칙). 반면 `reviewedAt`은
  실제 컬럼이므로 **넣는다**. 둘을 혼동하지 말 것.
- 기존 데이터를 백필하지 않는다 — `reviewed_at`이 NULL인 것이 "아직 검토 안 함"으로 맞다.
- **이 문서의 행 번호는 작업 시작 시점 원본 기준 참고값**이다. 앞 Task가 같은 파일을 고치면
  번호가 밀리므로, 위치는 항상 **인용된 코드 블록과 심볼 이름으로** 찾는다.
- 각 Task 끝에 `flutter analyze`(경고 0) + `flutter test`(전부 통과)를 확인하고 커밋한다.

## File Structure

| 파일 | 책임 | Task |
|---|---|---|
| `lib/core/database/database_helper.dart` | 스키마 v8 + `oldVersion < 8` 마이그레이션 | 1 |
| `lib/features/calendar/domain/calendar_event.dart` | `reviewedAt` 컬럼 필드 + `showsImportBadge` getter | 1 |
| `test/core/database/database_helper_test.dart` | v7 → v8 마이그레이션 그룹 | 1 |
| `test/features/calendar/data/calendar_repository_test.dart` | 스와이프 경로가 `reviewed_at`을 안 건드린다는 가드 | 1 |
| `lib/features/calendar/presentation/widgets/event_list_section.dart` | 배지 조건을 `showsImportBadge`로 | 2 |
| `test/features/calendar/event_list_import_badge_test.dart` | 검토된 항목엔 배지 없음 | 2 |
| `lib/features/calendar/presentation/widgets/event_edit_dialog.dart` | `_yearShifted` 상태 + 칩 게이트 + 저장 시 `reviewedAt` | 3 |
| `test/features/calendar/event_edit_dialog_year_test.dart` | 칩 1회용 (기존 "두 번 탭" 테스트 개정) | 3 |
| `test/features/calendar/event_edit_dialog_preserve_test.dart` | 저장하면 `reviewedAt`이 채워진다 | 3 |

**Task 의존 관계:** 1 → 2, 1 → 3. Task 2와 3은 서로 독립이다(목록 위젯 / 편집 시트).

---

### Task 1: DB v8 `reviewed_at` + 모델

컬럼과 모델 필드, 판정 getter를 만든다. UI는 아직 건드리지 않는다.

**Files:**
- Modify: `lib/core/database/database_helper.dart` (`_databaseVersion`, `_onUpgrade`, `_onCreate`)
- Modify: `lib/features/calendar/domain/calendar_event.dart` (생성자, `fromMap`, `toMap`, getter)
- Test: `test/core/database/database_helper_test.dart` (그룹 추가)
- Test: `test/features/calendar/data/calendar_repository_test.dart` (그룹 추가)

**Interfaces:**
- Consumes: `DatabaseHelper.tableCalendarEvents` 상수, `DatabaseHelper.forTesting(path:)`, `CalendarEvent.fromImport`(직전 작업의 파생 필드)
- Produces:
  - `CalendarEvent.reviewedAt` (`String?`, `@JsonKey(name: 'reviewed_at')`) — 실제 컬럼, `toMap()`에 포함
  - `CalendarEvent.showsImportBadge` (`bool` getter) — Task 2가 이 값으로 배지를 그린다

- [ ] **Step 1: 실패하는 마이그레이션 테스트 작성**

`test/core/database/database_helper_test.dart`의 `main()` 안, 기존 `마이그레이션 v6 → v7 (kind)`
그룹 **아래**에 추가한다. (파일 상단에 `dart:io`·`sqflite_common_ffi`·`test_database.dart` import가
이미 있다.)

```dart
  group('마이그레이션 v7 → v8 (reviewed_at)', () {
    late DatabaseHelper db;

    setUpAll(setUpFfiForTests);
    setUp(() => db = freshDatabaseHelper());
    tearDown(() async => db.close());

    Future<List<String>> columnsOf(String table) async {
      final d = await db.database;
      final rows = await d.rawQuery('PRAGMA table_info($table)');
      return rows.map((r) => r['name'] as String).toList();
    }

    test('calendar_events가 reviewed_at 컬럼을 갖는다', () async {
      expect(
        await columnsOf(DatabaseHelper.tableCalendarEvents),
        contains('reviewed_at'),
      );
    });

    test('schedules에는 추가하지 않는다 — 캘린더 이벤트의 검토 상태다', () async {
      expect(
        await columnsOf(DatabaseHelper.tableSchedules),
        isNot(contains('reviewed_at')),
      );
    });

    test('지정하지 않고 넣으면 NULL — 아직 검토하지 않음', () async {
      final d = await db.database;
      final now = DateTime.now().toIso8601String();
      await d.insert(DatabaseHelper.tableCalendarEvents, {
        'title': '학급편성 결과 제출',
        'event_date': '2026-03-02',
        'created_at': now,
        'updated_at': now,
      });

      final e = await d.query(DatabaseHelper.tableCalendarEvents);
      expect(e.single['reviewed_at'], isNull);
    });

    test('v7 DB의 기존 행은 업그레이드 후 reviewed_at이 NULL이다', () async {
      // :memory:는 연결을 닫으면 사라지므로 파일 DB가 필요하다.
      final dir = await Directory.systemTemp.createTemp('planroutine_v7');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/v7.db';

      final v7 = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 7,
          onCreate: (d, _) async {
            // v8이 손대는 테이블만 최소 컬럼으로 재현한다.
            await d.execute('''
              CREATE TABLE ${DatabaseHelper.tableCalendarEvents} (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                event_date TEXT NOT NULL
              )
            ''');
            await d.insert(DatabaseHelper.tableCalendarEvents, {
              'title': '작년에 가져온 업무',
              'event_date': '2026-03-02',
            });
          },
        ),
      );
      await v7.close();

      final helper = DatabaseHelper.forTesting(path: path);
      addTearDown(helper.close);
      final d = await helper.database;

      final rows = await d.query(DatabaseHelper.tableCalendarEvents);
      expect(rows.single['title'], '작년에 가져온 업무');
      expect(
        rows.single['reviewed_at'],
        isNull,
        reason: '기존 사용자의 항목은 아직 검토하지 않은 상태라 배지가 유지돼야 한다',
      );
    });
  });
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/core/database/database_helper_test.dart`
Expected: FAIL — `reviewed_at` 컬럼이 없어 `contains('reviewed_at')`가 실패

- [ ] **Step 3: 스키마 v8 적용**

`lib/core/database/database_helper.dart`에서 세 곳을 고친다.

(a) 버전 상수:

```dart
  static const _databaseVersion = 8;
```

(b) `_onCreate`의 `calendar_events` 정의에서 `kind TEXT NOT NULL DEFAULT 'task',` **다음 줄**에 추가:

```dart
        reviewed_at TEXT,
```

(c) `_onUpgrade`의 `if (oldVersion < 7) { ... }` 블록 **다음**에 추가:

```dart
    if (oldVersion < 8) {
      // 가져온 자료의 검토 상태. 편집 시트에서 저장하면 기록되고, 그때 `작년` 배지와
      // 연도 칩이 함께 꺼진다. 기존 행은 NULL이라 아직 검토하지 않은 것으로 남는다 —
      // 백필하지 않는 것이 곧 맞는 상태다.
      await db.execute(
        'ALTER TABLE $tableCalendarEvents ADD COLUMN reviewed_at TEXT',
      );
    }
```

- [ ] **Step 4: 마이그레이션 통과 확인**

Run: `flutter test test/core/database/database_helper_test.dart`
Expected: PASS (기존 그룹 + 신규 4건)

- [ ] **Step 5: 실패하는 모델 테스트 작성**

`test/features/calendar/data/calendar_repository_test.dart`의 `main()` 안, 기존 group들 아래에 추가한다.

```dart
  group('reviewed_at — 검토 상태', () {
    test('저장·조회 라운드트립에서 reviewedAt이 살아남는다', () async {
      final id = await repo.createEvent(buildEvent(title: '검토 대상'));
      final loaded = (await repo.getEventsByDate(DateTime(2026, 5, 1))).single;
      expect(loaded.reviewedAt, isNull, reason: '신규 이벤트는 아직 검토 전');

      await repo.updateEvent(
        loaded.copyWith(id: id, reviewedAt: '2026-07-26T10:00:00.000'),
      );

      final again = (await repo.getEventsByDate(DateTime(2026, 5, 1))).single;
      expect(again.reviewedAt, '2026-07-26T10:00:00.000');
    });

    test('showsImportBadge — 가져온 자료이면서 아직 검토 안 한 것만', () {
      const notImported = CalendarEvent(title: 'a', eventDate: '2026-05-01');
      const importedFresh = CalendarEvent(
        title: 'b',
        eventDate: '2026-05-01',
        fromImport: true,
      );
      const importedReviewed = CalendarEvent(
        title: 'c',
        eventDate: '2026-05-01',
        fromImport: true,
        reviewedAt: '2026-07-26T10:00:00.000',
      );

      expect(notImported.showsImportBadge, false);
      expect(importedFresh.showsImportBadge, true);
      expect(importedReviewed.showsImportBadge, false);
    });

    // 스와이프로 배지가 지워지지 않는다는 구조적 보장을 고정한다.
    // toMap()을 쓰는 쓰기 경로는 updateEvent 하나뿐이고, 나머지는 각자 컬럼만 쓴다.
    test('markCompleted·updateGoogleEventId는 reviewed_at을 건드리지 않는다', () async {
      final id = await repo.createEvent(buildEvent(title: '스와이프 대상'));
      final loaded = (await repo.getEventsByDate(DateTime(2026, 5, 1))).single;
      await repo.updateEvent(
        loaded.copyWith(id: id, reviewedAt: '2026-07-26T10:00:00.000'),
      );

      await repo.markCompleted(id);
      await repo.updateGoogleEventId(id, 'g-abc123');

      final after = (await repo.getEventsByDate(DateTime(2026, 5, 1))).single;
      expect(after.reviewedAt, '2026-07-26T10:00:00.000');
      expect(after.completedAt, isNotNull);
      expect(after.googleEventId, 'g-abc123');
    });
  });
```

- [ ] **Step 6: 실패 확인**

Run: `flutter test test/features/calendar/data/calendar_repository_test.dart`
Expected: FAIL — `CalendarEvent`에 `reviewedAt` 이름 인자와 `showsImportBadge`가 없어 컴파일 에러

- [ ] **Step 7: 모델에 필드·getter 추가**

`lib/features/calendar/domain/calendar_event.dart`에서:

(a) 생성자의 `@Default(EntryKind.task) EntryKind kind,` **다음**, `fromImport` doc comment **앞**에 추가:

```dart
    /// 사용자가 편집 시트에서 저장해 이 항목을 검토·정리한 시각. NULL이면 아직 손대지 않음.
    /// 무엇을 정리했는지(연도를 밀었는지, 보고 그냥 뒀는지)는 구분하지 않는다 —
    /// 저장했다는 것 자체가 검토의 증거다. `작년` 배지와 연도 칩이 이 값으로 함께 꺼진다.
    @JsonKey(name: 'reviewed_at') String? reviewedAt,
```

(b) `fromMap`의 `kind:` 줄 **다음**에 추가:

```dart
      reviewedAt: map['reviewed_at'] as String?,
```

(c) `toMap()`의 `'kind': kind.dbValue,` **다음**에 추가 (실제 컬럼이므로 **넣는다**):

```dart
      'reviewed_at': reviewedAt,
```

(d) 기존 `showsImportant` getter **다음**에 추가:

```dart
  /// 목록에 `작년` 배지를 노출할지. 가져온 자료이면서 아직 검토하지 않은 것만.
  /// 검토(편집 시트 저장)하면 꺼져, 남아 있는 배지가 곧 "아직 정리 안 한 목록"이 된다.
  bool get showsImportBadge => fromImport && reviewedAt == null;
```

Freezed 코드 재생성:

```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 8: 통과 확인**

Run: `flutter test test/features/calendar/data/calendar_repository_test.dart`
Expected: PASS (기존 테스트 + 신규 3건)

- [ ] **Step 9: 회귀 확인**

Run: `flutter analyze && flutter test`
Expected: analyze 경고 0 / 전체 통과. 특히 `toMap()`에 키가 하나 늘었으므로
`calendar_repository_test.dart`의 기존 `from_import` 부재 가드가 계속 통과해야 한다.

- [ ] **Step 10: 커밋**

```bash
git add lib/core/database/database_helper.dart \
        lib/features/calendar/domain/calendar_event.dart \
        lib/features/calendar/domain/calendar_event.freezed.dart \
        lib/features/calendar/domain/calendar_event.g.dart \
        test/core/database/database_helper_test.dart \
        test/features/calendar/data/calendar_repository_test.dart
git commit -m "feat(calendar): DB v8 reviewed_at — 가져온 자료의 검토 상태"
```

---

### Task 2: 목록 배지를 검토 상태로 게이트

`작년` 배지가 검토된 항목에서는 사라지게 한다. 모양·위치·문구는 그대로다.

**Files:**
- Modify: `lib/features/calendar/presentation/widgets/event_list_section.dart` (`_buildImportBadge`)
- Test: `test/features/calendar/event_list_import_badge_test.dart` (테스트 추가)

**Interfaces:**
- Consumes: Task 1의 `CalendarEvent.showsImportBadge` (`bool` getter)
- Produces: 없음

- [ ] **Step 1: 실패하는 테스트 추가**

`test/features/calendar/event_list_import_badge_test.dart`의 `캘린더 리스트 — 가져온 자료 배지`
그룹 안, 기존 테스트들 **아래**에 추가한다. (이 파일의 `pumpEvents` 헬퍼를 그대로 쓴다.)

```dart
    testWidgets('검토한 항목(reviewedAt 있음)에는 배지가 없다', (tester) async {
      await pumpEvents(tester, [
        CalendarEvent(
          id: 5,
          title: '$oldYear학년도 재학생 진급 사정 협의',
          eventDate: '$currentYear-01-03',
          fromImport: true,
          reviewedAt: '$currentYear-01-04T10:00:00.000',
        ),
      ]);

      expect(find.byKey(const Key('event_import_badge_5')), findsNothing);
      expect(find.text('작년'), findsNothing);
    });

    testWidgets('같은 목록에서 미검토는 배지, 검토 완료는 배지 없음', (tester) async {
      await pumpEvents(tester, [
        CalendarEvent(
          id: 6,
          title: '아직 안 본 항목',
          eventDate: '$currentYear-01-03',
          fromImport: true,
        ),
        CalendarEvent(
          id: 7,
          title: '정리한 항목',
          eventDate: '$currentYear-01-03',
          fromImport: true,
          reviewedAt: '$currentYear-01-04T10:00:00.000',
        ),
      ]);

      expect(find.byKey(const Key('event_import_badge_6')), findsOneWidget);
      expect(find.byKey(const Key('event_import_badge_7')), findsNothing);
      expect(
        find.text('작년'),
        findsOneWidget,
        reason: '남아 있는 배지가 곧 아직 정리 안 한 목록이다',
      );
    });
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/calendar/event_list_import_badge_test.dart`
Expected: FAIL — 배지가 `fromImport`만 보므로 `reviewedAt`이 있어도 렌더돼 `findsNothing`이 실패

- [ ] **Step 3: 배지 조건 교체**

`event_list_section.dart`의 `_buildImportBadge` 첫 줄을 바꾸고 doc comment를 갱신한다.

```dart
  /// 가져온 자료 중 **아직 검토하지 않은** 항목에 붙는 배지.
  ///
  /// 연도를 보지 않는다 — 제목에 연도가 없어도 붙는다. 편집 시트에서 저장하면
  /// (`reviewed_at` 기록) 사라지므로, 남아 있는 배지가 곧 "아직 정리 안 한 목록"이 된다.
  /// 누르는 것이 아니므로 조용해야 하고, 종류 배지(채움)와 한 행에서 구분되도록
  /// **테두리형**으로 그린다. 골드는 오늘·중요 전용이라 쓰지 않는다.
  Widget _buildImportBadge(CalendarEvent event) {
    if (!event.showsImportBadge) return const SizedBox.shrink();
```

나머지 본문(`Padding`부터)은 **건드리지 않는다.**

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/features/calendar/event_list_import_badge_test.dart`
Expected: PASS (기존 테스트 + 신규 2건)

- [ ] **Step 5: 회귀 확인**

Run: `flutter analyze && flutter test`
Expected: analyze 경고 0 / 전체 통과

- [ ] **Step 6: 커밋**

```bash
git add lib/features/calendar/presentation/widgets/event_list_section.dart \
        test/features/calendar/event_list_import_badge_test.dart
git commit -m "feat(calendar): 검토한 항목은 작년 배지를 뗀다"
```

---

### Task 3: 연도 칩 1회용 + 저장 시 검토 기록

시트 안에서 칩은 한 번만 눌린다. 저장하면 `reviewedAt`이 기록돼 다시 열어도 칩이 없고, 취소하면 되돌아간다.

**Files:**
- Modify: `lib/features/calendar/presentation/widgets/event_edit_dialog.dart` (`_yearShifted` 상태, `_buildYearShiftChip`, `_buildEvent`)
- Test: `test/features/calendar/event_edit_dialog_year_test.dart` (기존 "두 번 탭" 테스트 개정 + 추가)
- Test: `test/features/calendar/event_edit_dialog_preserve_test.dart` (그룹 추가)

**Interfaces:**
- Consumes: Task 1의 `CalendarEvent.reviewedAt` (`String?`)
- Produces: 없음

- [ ] **Step 1: 칩 테스트 개정 + 추가**

`test/features/calendar/event_edit_dialog_year_test.dart`의 `캘린더 이벤트 편집 — 연도 바꾸기 칩`
그룹에서 **기존 `'두 번 탭하면 두 해 밀린다'` 테스트를 다음으로 교체**한다(삭제가 아니라 개정 —
두 번 누르기가 이제 불가능해졌으므로 그 사실을 검증하는 테스트로 바꾼다).

```dart
    testWidgets('칩을 한 번 탭하면 칩이 사라진다 — 두 번 밀 수 없다', (tester) async {
      await pumpDialog(tester);
      await tester.enterText(titleField(), '$oldYear학년도 졸업식');
      await tester.pump();

      await tester.tap(find.byKey(const Key('year_shift_chip')));
      await tester.pump();

      expect(find.text('$currentYear학년도 졸업식'), findsOneWidget);
      expect(
        find.byKey(const Key('year_shift_chip')),
        findsNothing,
        reason: '연도 밀기는 한 번으로 끝난다 — 계속 눌러 연도가 올라가면 안 된다',
      );
    });

    testWidgets('칩을 탭한 뒤 제목을 다시 고쳐도 칩은 돌아오지 않는다', (tester) async {
      await pumpDialog(tester);
      await tester.enterText(titleField(), '$oldYear학년도 졸업식');
      await tester.pump();

      await tester.tap(find.byKey(const Key('year_shift_chip')));
      await tester.pump();
      await tester.enterText(titleField(), '$oldYear학년도 종업식');
      await tester.pump();

      expect(find.byKey(const Key('year_shift_chip')), findsNothing);
    });
```

그리고 같은 파일의 `캘린더 이벤트 편집 — 연도 칩은 수정 경로에서만` 그룹 안, 기존 테스트
**아래**에 추가한다. (`CalendarEvent` import가 이 파일에 이미 있다 — 없으면
`import 'package:planroutine/features/calendar/domain/calendar_event.dart';` 추가.)

```dart
    testWidgets('이미 검토한 항목(reviewedAt 있음)에는 칩이 없다', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: EventEditDialog(
                initialDate: DateTime(currentYear, 3, 2),
                event: CalendarEvent(
                  id: 2,
                  title: '$oldYear학년도 졸업식',
                  eventDate: '$currentYear-03-02',
                  reviewedAt: '$currentYear-03-03T10:00:00.000',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('year_shift_chip')), findsNothing);
    });
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/calendar/event_edit_dialog_year_test.dart`
Expected: FAIL — 탭 후에도 칩이 남아 있고(`findsNothing` 실패), `reviewedAt`이 있어도 칩이 뜬다

- [ ] **Step 3: 세션 상태 추가**

`event_edit_dialog.dart`의 `_EventEditDialogState`에서 `late EntryKind _kind;` 선언 **다음**에 추가:

```dart
  /// 이 시트에서 연도 칩을 이미 눌렀는지. 저장하지 않으므로 취소하면 사라진다 —
  /// 다시 열면 칩이 돌아온다. 시트 안에서 두 번 눌러 연도가 계속 올라가는 것을 막는다.
  bool _yearShifted = false;
```

- [ ] **Step 4: 칩 게이트 + 탭 동작 수정**

`_buildYearShiftChip()`의 doc comment와 게이트를 다음으로 바꾼다. `ValueListenableBuilder`
**바깥**에서 게이트해야 한다 — 안쪽이면 안 그릴 화면에서도 컨트롤러를 계속 구독한다.

```dart
  /// 제목에 연도가 있으면 나타나는 "연도 한 해 밀기" 원탭 칩.
  ///
  /// 컨트롤러를 구독해 입력 중에도 실시간으로 노출/숨김된다. 탭하면 제목의 **모든**
  /// 연도를 +1년 하고 커서를 끝으로 옮긴 뒤 **칩을 감춘다**(저장은 사용자가 직접).
  ///
  /// 꺼지는 이유가 셋이고 수명이 다르다:
  ///   - `!_isEditing` — 신규 생성은 방금 본인이 타이핑한 연도라 밀라고 권할 이유가 없다.
  ///   - `reviewedAt != null` — 이미 저장해 정리한 항목. **영구**(DB 컬럼).
  ///   - `_yearShifted` — 이 시트에서 이미 눌렀다. **세션 한정**이라 취소하면 돌아온다.
  Widget _buildYearShiftChip() {
    if (!_isEditing || _yearShifted) return const SizedBox.shrink();
    if (widget.event?.reviewedAt != null) return const SizedBox.shrink();
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
                setState(() => _yearShifted = true);
              },
            ),
          ),
        );
      },
    );
  }
```

- [ ] **Step 5: 칩 테스트 통과 확인**

Run: `flutter test test/features/calendar/event_edit_dialog_year_test.dart`
Expected: PASS. 기존 `'제목에 이전 연도를 입력하면 …'`·`'올해 연도에도 칩이 보인다'`·
`'연도가 없으면 칩이 없다'`·`'연도가 둘이면 …'`·`'칩을 탭하면 제목의 모든 연도가 …'`·
`'신규 생성 경로에서는 …'`이 그대로 통과해야 한다.

- [ ] **Step 6: 실패하는 저장 테스트 추가**

`test/features/calendar/event_edit_dialog_preserve_test.dart`의 `main()` 안, 기존 group들
아래에 추가한다. (이 파일의 `editTitleAndSave(tester, seed:, newTitle:)` 헬퍼를 그대로 쓴다 —
제목만 바꿔 저장하고 반환된 이벤트를 준다.)

```dart
  group('편집 저장 — 검토 시각 기록', () {
    testWidgets('칩을 누르지 않고 저장해도 reviewedAt이 채워진다', (tester) async {
      const seed = CalendarEvent(
        id: 11,
        title: '2025학년도 재학생 진급 사정 협의',
        eventDate: '2026-03-02',
      );

      final result = await editTitleAndSave(
        tester,
        seed: seed,
        newTitle: '2025학년도 재학생 진급 사정 협의(수정)',
      );

      expect(result, isNotNull);
      expect(
        result!.reviewedAt,
        isNotNull,
        reason: '열어보고 고칠 게 없다고 판단한 것도 검토다 — 아니면 연도 없는 제목의 '
            '배지를 지울 방법이 영원히 없다',
      );
    });

    testWidgets('신규 생성 저장에는 reviewedAt이 없다', (tester) async {
      CalendarEvent? captured;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    captured = await EventEditDialog.show(
                      context,
                      initialDate: DateTime(2026, 3, 2),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, '새 일정');
      await tester.ensureVisible(find.text('저장'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(
        captured!.reviewedAt,
        isNull,
        reason: '생성 시점에 검토란 개념이 없다',
      );
    });
  });
```

- [ ] **Step 7: 실패 확인**

Run: `flutter test test/features/calendar/event_edit_dialog_preserve_test.dart`
Expected: FAIL — `result.reviewedAt`이 `null`(저장 경로가 아직 기록하지 않음)

- [ ] **Step 8: 저장 시 검토 시각 기록**

`_buildEvent()`의 **편집 분기에만** `reviewedAt: now,`를 추가한다(`isImportant:` 다음 줄).
신규 생성 분기는 건드리지 않는다 — `null`로 남아야 한다.

```dart
    if (existing != null) {
      return existing.copyWith(
        title: _titleController.text.trim(),
        description: _trimmedDescription(),
        eventDate: formatDate(_eventDate),
        isImportant: _isImportant,
        kind: _kind,
        // 저장했다는 것 자체가 검토의 증거다. 이 값이 `작년` 배지와 연도 칩을 함께 끈다.
        reviewedAt: now,
        updatedAt: now,
      );
    }
```

`endDate`를 정리하는 기존 `staleEnd` 로직이 있으면 **그대로 둔다.**

- [ ] **Step 9: 통과 확인**

Run: `flutter test test/features/calendar/event_edit_dialog_preserve_test.dart`
Expected: PASS. **기존 보존 가드가 계속 통과해야 한다** —
`kind`·`googleEventId`·`deviceEventId`·`endDate`·`id`·`createdAt`.

- [ ] **Step 10: 회귀 확인**

Run: `flutter analyze && flutter test`
Expected: analyze 경고 0 / 전체 통과

- [ ] **Step 11: 커밋**

```bash
git add lib/features/calendar/presentation/widgets/event_edit_dialog.dart \
        test/features/calendar/event_edit_dialog_year_test.dart \
        test/features/calendar/event_edit_dialog_preserve_test.dart
git commit -m "feat(calendar): 연도 칩은 한 번만, 저장하면 검토 완료로 기록"
```

---

## 마무리

- [ ] **시뮬레이터 확인** (컨트롤러가 수행)
  1. 작년 항목을 열면 연도 칩이 있고, **한 번 탭하면 칩이 사라진다**
  2. 저장 → 목록에서 `작년` 배지가 사라진다
  3. 다시 열면 칩이 없다
  4. 다른 작년 항목에서 칩을 탭하고 **취소** → 다시 열면 칩이 있고 배지도 그대로다
  5. 완료 토글·Google 저장 스와이프로는 배지가 사라지지 않는다
- [ ] **CLAUDE.md 갱신** — "작년 배지" 항목을 고친다:
  - 판정 기준이 `source_id != null`에서 **`source_id != null && reviewed_at IS NULL`**로 바뀜
  - 배지의 의미가 **출처 표시 → 아직 정리 안 한 표시**로 바뀜(남은 배지가 할 일 목록)
  - `reviewed_at`은 실제 컬럼(v8)이고 `toMap()`에 **넣는다** — 파생 필드 `fromImport`와 반대
  - `toMap()`을 쓰는 경로가 `updateEvent` 하나뿐이라 스와이프로는 안 지워진다는 구조적 근거
  - 연도 칩이 꺼지는 세 이유(`!_isEditing` / `reviewedAt` / `_yearShifted`)와 각 수명
  - 데이터베이스 스키마 섹션에 v7→v8 마이그레이션 추가
- [ ] **릴리즈 노트** `docs/release_notes/1.2.0.ko.txt`에 사용자 언어로 1~2줄
- [ ] **`document-release` 스킬로 옵시디언 작업 로그 작성**
- [ ] 배포는 사용자 판단에 따름
