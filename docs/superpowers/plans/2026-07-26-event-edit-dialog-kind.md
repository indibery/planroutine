# 일정 시트 재편 (종류 분리 · 종료일 제거 · 설명 확대) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 캘린더 일정 추가/수정 시트에서 업무·학교일정을 고를 수 있게 하고, 쓰이지 않는 종료일 입력을 없애 그 자리를 설명칸에 넘기며, 편집 저장 시 필드가 조용히 유실되던 버그를 구조적으로 차단한다.

**Architecture:** `EventEditDialog`의 하단에 "성격 카드"(종류 세그먼트 + 중요 스위치)를 두고, 오늘 탭에서 열 때는 종류 행만 숨긴다(`allowKindChange: false`). `_buildEvent()`를 생성자 조립에서 `copyWith` 기반으로 바꿔 편집 시 손대지 않는 필드가 자동 보존되게 한다. 캘린더 목록 행은 제목 앞 인라인 배지로 종류를 보여주고, 세로 한 줄을 쓰던 `★ 중요` 배지는 ★ 아이콘만 남겨 같은 줄에 합친다.

**Tech Stack:** Flutter 3.x / Dart, Riverpod, Freezed(`CalendarEvent`), sqflite, flutter_test + integration_test

**설계 스펙:** `docs/superpowers/specs/2026-07-26-event-edit-dialog-kind-design.md`

## Global Constraints

- 상태 관리는 **Riverpod만** 사용한다. 다른 라이브러리 금지.
- **`lib/` 안에서는 `!` 강제 언래핑 금지.** nullable은 지역 변수로 받아 null 체크 후 사용한다.
  (테스트 코드는 예외 — 이 리포의 기존 테스트가 `result!.isImportant` 형태를 일관되게 쓴다.)
- **이 문서의 행 번호는 작업 시작 시점 원본 기준 참고값**이다. 앞 Task가 같은 파일을 고치면
  번호가 밀리므로, 위치는 항상 **인용된 코드 블록과 심볼 이름으로** 찾는다.
- 하드코딩 금지: 색은 `AppColors`, 크기는 `AppSizes`, 문자열은 `AppStrings` / 도메인별 `*Strings` 클래스.
- 파일명 snake_case, 클래스명 PascalCase, **한글 UI + 한글 주석**.
- **기존 테스트 삭제 금지.** 동작이 바뀌어 깨지는 테스트는 새 동작에 맞게 **수정**한다.
- 골드(`AppColors.gold` / `goldFill`)는 **오늘·중요 강조 전용**. 종류 구분에 쓰지 않는다.
- 골드 채움 위 글씨·아이콘은 `AppColors.onGold`, 배경 위 골드 텍스트/아이콘은 `AppColors.gold`.
- 각 Task 끝에 `flutter analyze`(경고 0) + `flutter test`(전부 통과)를 확인하고 커밋한다.
- 용어는 **일정 / 학교일정 / 업무**만 쓴다. "행사"는 쓰지 않는다.

## File Structure

| 파일 | 책임 | Task |
|---|---|---|
| `lib/features/schedule/presentation/widgets/kind_badge.dart` (신규) | 업무/학교일정 배지 한 개. 입력 탭·캘린더가 공유 | 1 |
| `lib/features/schedule/presentation/widgets/schedule_tile.dart` (수정) | 자체 `_buildKindBadge` 제거 → `KindBadge` 사용 | 1 |
| `lib/shared/widgets/segmented_setting_row.dart` (이동) | 아이콘+라벨+세그먼트 한 줄. 설정·캘린더 공유 | 2 |
| `lib/features/calendar/presentation/widgets/event_edit_dialog.dart` (수정) | 시트 본체 — copyWith 전환, 종료일 제거, 설명 확대, 성격 카드 | 3·4·5 |
| `lib/core/constants/strings/calendar_strings.dart` (수정) | `eventEndDate` 제거, `kindLabel` 추가 | 4·5 |
| `lib/features/today/presentation/screens/today_screen.dart` (수정) | 시트 호출 2곳에 `allowKindChange: false` | 5 |
| `lib/features/calendar/presentation/widgets/event_list_section.dart` (수정) | 목록 행 — 종류 배지 + ★ 인라인 | 6 |

**Task 의존 관계:** 1 → 6, 2 → 5, 3 → 4 → 5. Task 1·2·3은 서로 독립이다.

---

### Task 1: KindBadge 공유 위젯 추출

`schedule_tile`의 배지를 위젯으로 빼서 Task 6의 캘린더 목록이 같은 것을 쓰게 한다.

**Files:**
- Create: `lib/features/schedule/presentation/widgets/kind_badge.dart`
- Modify: `lib/features/schedule/presentation/widgets/schedule_tile.dart:8, 93, 188-212`
- Test: `test/features/schedule/kind_badge_test.dart` (신규)

**Interfaces:**
- Consumes: `EntryKind`(`lib/features/schedule/domain/entry_kind.dart`) — `label`, enum 값 `task`/`event`
- Produces: `class KindBadge extends StatelessWidget { const KindBadge({super.key, required EntryKind kind}); }`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/features/schedule/kind_badge_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/features/schedule/domain/entry_kind.dart';
import 'package:planroutine/features/schedule/presentation/widgets/kind_badge.dart';

void main() {
  Future<void> pump(WidgetTester tester, EntryKind kind) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: KindBadge(kind: kind))),
      ),
    );
  }

  Color badgeTextColor(WidgetTester tester) {
    return tester.widget<Text>(find.byType(Text)).style!.color!;
  }

  group('KindBadge', () {
    testWidgets('업무는 짧은 라벨 "업무" + 회색 계열', (tester) async {
      await pump(tester, EntryKind.task);

      expect(find.text('업무'), findsOneWidget);
      expect(badgeTextColor(tester), AppColors.sub);
    });

    testWidgets('학교일정은 짧은 라벨 "일정" + 파랑 계열', (tester) async {
      await pump(tester, EntryKind.event);

      expect(find.text('일정'), findsOneWidget);
      expect(badgeTextColor(tester), AppColors.info);
    });
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/schedule/kind_badge_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../kind_badge.dart'` (컴파일 에러)

- [ ] **Step 3: KindBadge 작성**

`lib/features/schedule/presentation/widgets/kind_badge.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/entry_kind.dart';

/// 업무 / 학교일정 배지 — 입력 탭 검토 목록과 캘린더 목록이 공유한다.
///
/// 옅은배경(15%) + 진한글씨 형이라 다크/라이트 양쪽에서 대비가 안정적이다.
/// 골드는 오늘·중요 전용이라 쓰지 않는다.
///
/// `shared/widgets/`가 아니라 schedule feature에 두는 이유: 이 배지는 [EntryKind]에
/// 종속인데 `shared/widgets/` 아래 어떤 위젯도 `features/`를 import 하지 않는다.
/// 캘린더는 이미 schedule 도메인에 의존하므로(calendar_event.dart) 여기서 가져다 쓴다.
class KindBadge extends StatelessWidget {
  const KindBadge({super.key, required this.kind});

  final EntryKind kind;

  @override
  Widget build(BuildContext context) {
    final color = kind == EntryKind.event ? AppColors.info : AppColors.sub;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      ),
      child: Text(
        kind.label,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/features/schedule/kind_badge_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: schedule_tile을 새 위젯으로 교체**

`schedule_tile.dart:93` — `_buildKindBadge(schedule.kind),` 를 다음으로 바꾼다:

```dart
                          KindBadge(kind: schedule.kind),
```

`schedule_tile.dart:188-212`의 `_buildKindBadge` 메서드 전체(주석 3줄 포함)를 **삭제**한다.

import 정리 — 파일 상단에 추가:

```dart
import 'kind_badge.dart';
```

`import '../../domain/entry_kind.dart';`(8행)은 `EntryKind` 타입을 더 이상 직접 쓰지 않으므로
**삭제**한다. (`schedule.kind`는 타입명을 적지 않는다)

- [ ] **Step 6: 기존 테스트가 그대로 통과하는지 확인**

Run: `flutter analyze && flutter test`
Expected: analyze 경고 0 / 전체 테스트 통과 (배지는 모양이 같으므로 기존 입력 탭 테스트가 깨지면 안 된다)

- [ ] **Step 7: 커밋**

```bash
git add lib/features/schedule/presentation/widgets/kind_badge.dart \
        lib/features/schedule/presentation/widgets/schedule_tile.dart \
        test/features/schedule/kind_badge_test.dart
git commit -m "refactor(schedule): 종류 배지를 KindBadge 위젯으로 추출"
```

---

### Task 2: SegmentedSettingRow를 shared/widgets로 이동

Task 5에서 캘린더 시트가 쓰게 되므로, 설정 전용 자리에서 공유 자리로 옮긴다.
이 위젯은 `features/`를 import 하지 않아 `shared/`로 가도 의존 방향 문제가 없다.

**Files:**
- Move: `lib/features/settings/presentation/widgets/segmented_setting_row.dart` → `lib/shared/widgets/segmented_setting_row.dart`
- Modify: `lib/features/settings/presentation/widgets/theme_mode_tile.dart`, `lib/features/settings/presentation/widgets/stamp_settings_tiles.dart`

**Interfaces:**
- Produces: `SegmentedSettingRow<T>({Key? key, required IconData icon, required String label, required List<ButtonSegment<T>> segments, required T selected, required ValueChanged<T> onChanged})` — Task 5가 `T = EntryKind`로 쓴다.

- [ ] **Step 1: 파일 이동**

```bash
git mv lib/features/settings/presentation/widgets/segmented_setting_row.dart \
       lib/shared/widgets/segmented_setting_row.dart
```

- [ ] **Step 2: 옮긴 파일의 상대 경로 import 수정**

`lib/shared/widgets/segmented_setting_row.dart` 상단 2줄을 깊이에 맞게 고친다
(`features/settings/presentation/widgets/`는 4단계, `shared/widgets/`는 2단계):

```dart
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
```

- [ ] **Step 3: 사용처 2곳의 import 수정**

`lib/features/settings/presentation/widgets/theme_mode_tile.dart` 와
`lib/features/settings/presentation/widgets/stamp_settings_tiles.dart` 에서

```dart
import 'segmented_setting_row.dart';
```

를 다음으로 바꾼다:

```dart
import '../../../../shared/widgets/segmented_setting_row.dart';
```

- [ ] **Step 4: 검증**

Run: `flutter analyze && flutter test`
Expected: analyze 경고 0 / 전체 테스트 통과 (동작 변화 없음, 경로만 이동)

- [ ] **Step 5: 커밋**

```bash
git add -A lib/shared/widgets/segmented_setting_row.dart \
           lib/features/settings/presentation/widgets/
git commit -m "refactor(shared): SegmentedSettingRow를 shared/widgets로 이동"
```

---

### Task 3: `_buildEvent()` copyWith 전환 + 보존 가드

**이 Task 하나로 버그가 고쳐진다.** 편집 저장 시 `kind`·`googleEventId`·`deviceEventId`가
`@Default`/`null`로 되돌아가 DB를 덮던 문제를 없앤다.

**Files:**
- Modify: `lib/features/calendar/presentation/widgets/event_edit_dialog.dart:428-448`
- Test: `test/features/calendar/event_edit_dialog_preserve_test.dart` (신규)

**Interfaces:**
- Consumes: `CalendarEvent`(Freezed `copyWith`), `formatDate(DateTime) → 'YYYY-MM-DD'`(`core/utils/date_utils.dart`)
- Produces: 없음 (내부 리팩터). Task 4·5가 같은 메서드를 이어서 고친다.

- [ ] **Step 1: 실패하는 보존 가드 테스트 작성**

`test/features/calendar/event_edit_dialog_preserve_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/features/calendar/presentation/widgets/event_edit_dialog.dart';
import 'package:planroutine/features/schedule/domain/entry_kind.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR', null);
  });

  /// 시트를 열어 제목만 [newTitle]로 바꾸고 저장한 뒤, 반환된 이벤트를 준다.
  Future<CalendarEvent?> editTitleAndSave(
    WidgetTester tester, {
    required CalendarEvent seed,
    required String newTitle,
  }) async {
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
                    event: seed,
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

    await tester.enterText(find.byType(TextFormField).first, newTitle);
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    return captured;
  }

  group('편집 저장 — 손대지 않은 필드 보존 가드', () {
    // 이 테스트가 재발 방지선이다. _buildEvent()가 생성자로 CalendarEvent를 새로
    // 만들면 여기 적힌 필드들이 @Default/null로 되돌아가 DB를 덮는다.
    //   - kind 유실 → 학교일정이 업무가 되어 오늘 탭에 뜬다
    //   - googleEventId 유실 → 재저장 시 Google 캘린더에 중복 이벤트가 생긴다
    testWidgets('제목만 고쳐 저장해도 kind·googleEventId·deviceEventId·endDate가 남는다',
        (tester) async {
      const seed = CalendarEvent(
        id: 7,
        title: '2025학년도 가을 운동회',
        eventDate: '2026-03-02',
        endDate: '2026-03-04',
        googleEventId: 'g-abc123',
        deviceEventId: 'd-xyz789',
        kind: EntryKind.event,
        createdAt: '2026-01-01T00:00:00.000',
      );

      final result = await editTitleAndSave(
        tester,
        seed: seed,
        newTitle: '2026학년도 가을 운동회',
      );

      expect(result, isNotNull);
      expect(result!.title, '2026학년도 가을 운동회');
      expect(result.kind, EntryKind.event, reason: '학교일정이 업무로 바뀌면 안 된다');
      expect(result.googleEventId, 'g-abc123');
      expect(result.deviceEventId, 'd-xyz789');
      expect(result.endDate, '2026-03-04');
      expect(result.id, 7);
      expect(result.createdAt, '2026-01-01T00:00:00.000');
    });
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/calendar/event_edit_dialog_preserve_test.dart`
Expected: FAIL — `result.kind`가 `EntryKind.task`, `result.googleEventId`가 `null`

- [ ] **Step 3: `_buildEvent()`를 copyWith 기반으로 교체**

`event_edit_dialog.dart:428-448`의 `_buildEvent()` 전체를 다음으로 바꾼다:

```dart
  /// 저장할 이벤트를 만든다.
  ///
  /// 편집일 때는 **반드시 copyWith**를 쓴다. 생성자로 새로 만들면 시트가 모르는 필드가
  /// `@Default`/null로 되돌아가고, `updateEvent`의 `toMap()`이 그 값으로 DB를 덮는다
  /// (kind → 학교일정이 업무로, googleEventId → Google 중복 이벤트).
  /// `CalendarEvent`에 필드가 추가돼도 여기를 고칠 필요가 없어야 한다.
  CalendarEvent _buildEvent() {
    final now = DateTime.now().toIso8601String();
    final end = _endDate;
    final endDateStr = end != null ? formatDate(end) : null;
    final existing = widget.event;

    if (existing != null) {
      return existing.copyWith(
        title: _titleController.text.trim(),
        description: _trimmedDescription(),
        eventDate: formatDate(_eventDate),
        endDate: endDateStr,
        isImportant: _isImportant,
        updatedAt: now,
      );
    }

    return CalendarEvent(
      title: _titleController.text.trim(),
      description: _trimmedDescription(),
      eventDate: formatDate(_eventDate),
      endDate: endDateStr,
      isAllDay: true,
      isImportant: _isImportant,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 설명은 비어 있으면 null로 저장한다(빈 문자열을 남기지 않는다).
  String? _trimmedDescription() {
    final text = _descriptionController.text.trim();
    return text.isEmpty ? null : text;
  }
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/features/calendar/event_edit_dialog_preserve_test.dart`
Expected: PASS (1 test)

- [ ] **Step 5: 회귀 확인**

Run: `flutter analyze && flutter test`
Expected: analyze 경고 0 / 전체 통과 (특히 `event_edit_dialog_important_test.dart` 2건)

- [ ] **Step 6: 커밋**

```bash
git add lib/features/calendar/presentation/widgets/event_edit_dialog.dart \
        test/features/calendar/event_edit_dialog_preserve_test.dart
git commit -m "fix(calendar): 편집 저장 시 kind·googleEventId·deviceEventId 유실 차단"
```

---

### Task 4: 종료 날짜 입력 제거 + 설명칸 확대

앱 안에서 아무 일도 하지 않는 종료일 입력을 없애고(48+8px 회수), 그 자리를 설명칸에 넘긴다
(2줄 → 4~6줄). **DB 컬럼·모델·Google 내보내기 경로는 그대로 둔다** — 기존에 기간이 설정된
이벤트는 Task 3의 copyWith가 계속 보존한다.

**Files:**
- Modify: `lib/features/calendar/presentation/widgets/event_edit_dialog.dart:61, 73, 119, 121, 232-262, 390-411, 431-433`
- Modify: `lib/core/constants/strings/calendar_strings.dart:16`
- Test: `test/features/calendar/event_edit_dialog_preserve_test.dart` (Task 3 파일에 추가)

**Interfaces:**
- Consumes: Task 3의 `_buildEvent()` / `_trimmedDescription()`
- Produces: 없음

- [ ] **Step 1: 실패하는 테스트 추가**

`test/features/calendar/event_edit_dialog_preserve_test.dart`의 `main()` 안, 기존 group 아래에
다음 group을 추가한다:

```dart
  group('종료 날짜 입력 제거', () {
    Future<void> pumpSheet(WidgetTester tester, {CalendarEvent? event}) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: EventEditDialog(
                initialDate: DateTime(2026, 3, 2),
                event: event,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('시트에 "종료 날짜" 타일이 없다', (tester) async {
      await pumpSheet(tester);

      expect(find.text('종료 날짜'), findsNothing);
      expect(find.text('날짜'), findsOneWidget);
    });

    testWidgets('설명칸은 최소 4줄 높이로 열린다', (tester) async {
      await pumpSheet(tester);

      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byType(TextFormField).last,
          matching: find.byType(TextField),
        ),
      );
      expect(field.minLines, 4);
      expect(field.maxLines, 6);
    });
  });
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/calendar/event_edit_dialog_preserve_test.dart`
Expected: FAIL — `find.text('종료 날짜')`가 1개 발견됨 / `minLines`가 null

- [ ] **Step 3: 종료일 상태·UI 제거**

`event_edit_dialog.dart`에서 순서대로 고친다.

(a) 61행 `DateTime? _endDate;` **삭제**
(b) 73행 `_endDate = event?.endDate != null ? event?.endDateTime : null;` **삭제**
(c) 232-241행 `_buildDescriptionField()`의 `maxLines: 2,`를 다음으로 교체:

```dart
      minLines: 4,
      maxLines: 6,
```

(d) 243-262행 `_buildDateRow()` 전체를 다음으로 교체 (종료일 타일 + `formatter` 지역변수 제거):

```dart
  Widget _buildDateRow() {
    return _buildDateTile(
      label: CalendarStrings.eventDate,
      date: _eventDate,
      onTap: _pickDate,
    );
  }
```

(e) 390-411행 `_pickDate({required bool isStart})` 전체를 다음으로 교체:

```dart
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('ko', 'KR'),
    );
    if (picked != null) {
      setState(() => _eventDate = picked);
    }
  }
```

(f) Task 3에서 만든 `_buildEvent()`에서 종료일 관련 3줄을 정리한다.
`final end = _endDate;` 와 `final endDateStr = end != null ? formatDate(end) : null;` 를
**삭제**하고, 두 곳의 `endDate: endDateStr,` 줄도 **삭제**한다.

> 편집 경로는 `copyWith`가 `endDate`를 자동 보존한다. 신규 경로는 생성자 기본값 `null`이다.

- [ ] **Step 4: 문자열 제거**

`lib/core/constants/strings/calendar_strings.dart:16`의

```dart
  static const eventEndDate = '종료 날짜';
```

줄을 **삭제**한다.

- [ ] **Step 5: 통과 확인**

Run: `flutter test test/features/calendar/event_edit_dialog_preserve_test.dart`
Expected: PASS (3 tests — 보존 가드 1 + 신규 2). 보존 가드의 `endDate` 검증이 계속 통과해야 한다.

- [ ] **Step 6: 회귀 확인**

Run: `flutter analyze && flutter test`
Expected: analyze 경고 0 (`_endDate`·`eventEndDate` 미사용 경고가 남지 않아야 한다) / 전체 통과

- [ ] **Step 7: 커밋**

```bash
git add lib/features/calendar/presentation/widgets/event_edit_dialog.dart \
        lib/core/constants/strings/calendar_strings.dart \
        test/features/calendar/event_edit_dialog_preserve_test.dart
git commit -m "feat(calendar): 종료 날짜 입력 제거하고 설명칸을 4~6줄로 확대"
```

---

### Task 5: 성격 카드 — 업무 / 학교일정 선택

중요 토글 컨테이너를 "성격 카드"로 확장해 종류 세그먼트를 얹는다. 오늘 탭에서 열 때는
종류 행과 구분선을 숨겨 지금과 똑같이 보이게 한다.

**Files:**
- Modify: `lib/features/calendar/presentation/widgets/event_edit_dialog.dart:18-53, 56-75, 123, 312-338, 428-448`
- Modify: `lib/core/constants/strings/calendar_strings.dart` (중요 표시 섹션 근처)
- Modify: `lib/features/today/presentation/screens/today_screen.dart:75, 88`
- Test: `test/features/calendar/event_edit_dialog_kind_test.dart` (신규)

**Interfaces:**
- Consumes: Task 2의 `SegmentedSettingRow<T>`, `EntryKind`(`filterLabel`), Task 3의 `_buildEvent()`
- Produces: `EventEditDialog({..., bool allowKindChange = true})` 및 `EventEditDialog.show(context, {required DateTime initialDate, CalendarEvent? event, bool allowKindChange = true})`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/features/calendar/event_edit_dialog_kind_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/features/calendar/presentation/widgets/event_edit_dialog.dart';
import 'package:planroutine/features/schedule/domain/entry_kind.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR', null);
  });

  const kindSelector = Key('kind_selector');

  Future<CalendarEvent?> openAndSave(
    WidgetTester tester, {
    CalendarEvent? event,
    bool allowKindChange = true,
    String? title,
    Future<void> Function(WidgetTester tester)? beforeSave,
  }) async {
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
                    event: event,
                    allowKindChange: allowKindChange,
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

    if (title != null) {
      await tester.enterText(find.byType(TextFormField).first, title);
    }
    if (beforeSave != null) {
      await beforeSave(tester);
    }
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    return captured;
  }

  group('종류 선택 — 캘린더 경로(선택 가능)', () {
    testWidgets('종류 행이 보이고 기본값은 업무', (tester) async {
      final result = await openAndSave(tester, title: '교육계획 수립');

      expect(result, isNotNull);
      expect(result!.kind, EntryKind.task);
    });

    testWidgets('학교일정을 고르고 저장하면 kind=event', (tester) async {
      final result = await openAndSave(
        tester,
        title: '가을 운동회',
        beforeSave: (tester) async {
          await tester.tap(find.text('학교일정'));
          await tester.pumpAndSettle();
        },
      );

      expect(result, isNotNull);
      expect(result!.kind, EntryKind.event);
    });

    testWidgets('기존 학교일정을 열면 학교일정이 선택돼 있고 저장해도 유지된다',
        (tester) async {
      final result = await openAndSave(
        tester,
        event: const CalendarEvent(
          id: 3,
          title: '학예회',
          eventDate: '2026-03-02',
          kind: EntryKind.event,
        ),
      );

      expect(result, isNotNull);
      expect(result!.kind, EntryKind.event);
    });
  });

  group('종류 선택 — 오늘 탭 경로(잠금)', () {
    // 오늘 탭은 업무만 담는 화면이다. 여기서 학교일정을 만들면 저장 직후
    // 목록에서 사라져 "저장이 안 됐나?"로 읽힌다 — 아예 못 고르게 잠근다.
    testWidgets('종류 행이 없고 신규는 업무로 저장된다', (tester) async {
      final result = await openAndSave(
        tester,
        allowKindChange: false,
        title: '주간학습안내 작성',
      );

      expect(find.byKey(kindSelector), findsNothing);
      expect(result, isNotNull);
      expect(result!.kind, EntryKind.task);
    });

    testWidgets('종류 행이 없어도 기존 이벤트의 kind는 보존된다', (tester) async {
      final result = await openAndSave(
        tester,
        allowKindChange: false,
        event: const CalendarEvent(
          id: 9,
          title: '체육대회',
          eventDate: '2026-03-02',
          kind: EntryKind.event,
        ),
      );

      expect(find.byKey(kindSelector), findsNothing);
      expect(result, isNotNull);
      expect(result!.kind, EntryKind.event);
    });
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/calendar/event_edit_dialog_kind_test.dart`
Expected: FAIL — `EventEditDialog.show`에 `allowKindChange` 명명 인자가 없어 컴파일 에러

- [ ] **Step 3: 문자열 추가**

`lib/core/constants/strings/calendar_strings.dart`의 `// 중요 표시` 섹션 **위**에 추가:

```dart
  // 업무 / 학교일정
  static const kindLabel = '종류';
```

- [ ] **Step 4: 위젯에 allowKindChange + _kind 추가**

(a) `event_edit_dialog.dart` 상단 import에 추가:

```dart
import '../../../../shared/widgets/segmented_setting_row.dart';
import '../../../schedule/domain/entry_kind.dart';
```

(b) 생성자(18-26행)에 필드 추가:

```dart
class EventEditDialog extends ConsumerStatefulWidget {
  const EventEditDialog({
    super.key,
    required this.initialDate,
    this.event,
    this.allowKindChange = true,
  });

  final DateTime initialDate;
  final CalendarEvent? event;

  /// 종류(업무/학교일정) 선택 행을 노출할지.
  ///
  /// 오늘 탭은 업무만 담는 화면이라 `false`로 잠근다 — 거기서 학교일정을 만들면
  /// 저장 직후 목록에서 사라져 저장 실패로 읽힌다. 잠가도 `_kind` 상태는 살아 있어
  /// 기존 이벤트를 편집할 때 원래 종류가 보존된다.
  final bool allowKindChange;
```

(c) `show()`(29-50행)에 인자를 통과시킨다:

```dart
  static Future<CalendarEvent?> show(
    BuildContext context, {
    required DateTime initialDate,
    CalendarEvent? event,
    bool allowKindChange = true,
  }) {
    return showModalBottomSheet<CalendarEvent>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: AppColors.navyMid,
      barrierColor: AppColors.navy.withValues(alpha: 0.7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radius28),
        ),
      ),
      builder: (_) => EventEditDialog(
        initialDate: initialDate,
        event: event,
        allowKindChange: allowKindChange,
      ),
    );
  }
```

(d) State에 `_kind` 필드를 추가하고(`_isImportant` 옆) `initState`에서 초기화:

```dart
  late bool _isImportant;
  late EntryKind _kind;
```

```dart
    _isImportant = event?.isImportant ?? false;
    _kind = event?.kind ?? EntryKind.task;
```

- [ ] **Step 5: 중요 토글을 성격 카드로 확장**

`build()`의 `_buildImportantToggle(),`(123행)을 다음으로 교체:

```dart
                _buildAttributesCard(),
```

312-338행의 `_buildImportantToggle()` 전체를 다음으로 교체:

```dart
  /// 성격 카드 — "이 항목이 어떤 성격인가"를 정하는 값들을 한 테두리에 묶는다.
  ///
  /// 종류(업무/학교일정) + 중요 표시. [EventEditDialog.allowKindChange]가 false면
  /// 종류 행과 구분선을 함께 뺀다 — 구분선만 남으면 뭔가 잘린 것처럼 읽힌다.
  Widget _buildAttributesCard() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSizes.radius12),
      ),
      child: Column(
        children: [
          if (widget.allowKindChange) ...[
            SegmentedSettingRow<EntryKind>(
              key: const Key('kind_selector'),
              icon: Icons.label_outline,
              label: CalendarStrings.kindLabel,
              segments: EntryKind.values
                  .map((k) => ButtonSegment<EntryKind>(
                        value: k,
                        label: Text(k.filterLabel),
                      ))
                  .toList(),
              selected: _kind,
              onChanged: (k) => setState(() => _kind = k),
            ),
            Divider(height: 1, color: AppColors.border),
          ],
          SwitchListTile(
            key: const Key('important_toggle'),
            value: _isImportant,
            onChanged: (v) => setState(() => _isImportant = v),
            activeThumbColor: AppColors.gold,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSizes.spacing16,
            ),
            secondary: Icon(Icons.star_rounded, color: AppColors.gold),
            title: Text(
              CalendarStrings.importantLabel,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 6: `_buildEvent()`에 kind 반영**

Task 3에서 만든 두 분기 모두에 `kind: _kind,`를 추가한다 (`isImportant:` 줄 바로 아래).

- [ ] **Step 7: 오늘 탭 호출부 잠금**

`lib/features/today/presentation/screens/today_screen.dart:75` — FAB 추가:

```dart
    final result = await EventEditDialog.show(
      context,
      initialDate: DateTime.now(),
      allowKindChange: false,
    );
```

같은 파일 88행 — 본문 탭 편집:

```dart
    final result = await EventEditDialog.show(
      context,
      initialDate: event.eventDateTime,
      event: event,
      allowKindChange: false,
    );
```

- [ ] **Step 8: 통과 확인**

Run: `flutter test test/features/calendar/event_edit_dialog_kind_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 9: 회귀 확인**

Run: `flutter analyze && flutter test`
Expected: analyze 경고 0 / 전체 통과. `event_edit_dialog_important_test.dart`가 쓰는
`Key('important_toggle')`은 그대로라 깨지지 않아야 한다.

- [ ] **Step 10: 커밋**

```bash
git add lib/features/calendar/presentation/widgets/event_edit_dialog.dart \
        lib/core/constants/strings/calendar_strings.dart \
        lib/features/today/presentation/screens/today_screen.dart \
        test/features/calendar/event_edit_dialog_kind_test.dart
git commit -m "feat(calendar): 일정 시트에 업무/학교일정 선택 추가 (오늘 탭은 업무 고정)"
```

---

### Task 6: 캘린더 목록 — 종류 배지 + ★ 인라인

목록에서 업무/학교일정이 보이게 하고, 세로 한 줄을 쓰던 `★ 중요` 배지를 ★ 아이콘만
같은 줄로 옮긴다. **월 그리드 점은 건드리지 않는다.**

**Files:**
- Modify: `lib/features/calendar/presentation/widgets/event_list_section.dart:209-229, 305-316`
- Modify: `test/features/calendar/event_list_important_test.dart`
- Modify: `integration_test/app_test.dart:349`
- Test: `test/features/calendar/event_list_kind_test.dart` (신규)

**Interfaces:**
- Consumes: Task 1의 `KindBadge({required EntryKind kind})`, `CalendarEvent.kind`, `CalendarEvent.showsImportant`
- Produces: 없음

- [ ] **Step 1: 실패하는 종류 배지 테스트 작성**

`test/features/calendar/event_list_kind_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/features/calendar/presentation/widgets/event_list_section.dart';
import 'package:planroutine/features/schedule/domain/entry_kind.dart';
import 'package:planroutine/features/schedule/presentation/widgets/kind_badge.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR', null);
  });

  Future<void> pump(WidgetTester tester, List<CalendarEvent> events) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EventListSection(
                selectedDate: DateTime(2026, 3, 2),
                events: events,
                onEventTap: (_) {},
                onEventSaveToGoogle: null,
                onEventToggleCompleted: (_) {},
                onEventBumpYear: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  double cardHeight(WidgetTester tester, int id) {
    return tester.getSize(find.byKey(Key('event_card_$id'))).height;
  }

  group('목록 — 업무 / 학교일정 구분', () {
    testWidgets('업무 행과 학교일정 행에 각각 배지가 붙는다', (tester) async {
      await pump(tester, const [
        CalendarEvent(
          id: 1,
          title: '교육계획 수립',
          eventDate: '2026-03-02',
        ),
        CalendarEvent(
          id: 2,
          title: '가을 운동회',
          eventDate: '2026-03-02',
          kind: EntryKind.event,
        ),
      ]);

      expect(find.byType(KindBadge), findsNWidgets(2));
      expect(find.text('업무'), findsOneWidget);
      expect(find.text('일정'), findsOneWidget);
    });

    testWidgets('중요 행에도 종류 배지가 함께 보이고 제목이 넘치지 않는다',
        (tester) async {
      await pump(tester, const [
        CalendarEvent(
          id: 3,
          title: '2026학년도 학교교육계획 수립 및 심의 요청',
          eventDate: '2026-03-02',
          isImportant: true,
        ),
      ]);

      expect(find.byType(KindBadge), findsOneWidget);
      expect(find.byKey(const Key('event_important_badge_3')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('목록 — 중요 표시는 세로를 쓰지 않는다', () {
    testWidgets('중요 행과 보통 행의 높이가 같다', (tester) async {
      await pump(tester, const [
        CalendarEvent(id: 4, title: '보통 일정', eventDate: '2026-03-02'),
        CalendarEvent(
          id: 5,
          title: '중요 일정',
          eventDate: '2026-03-02',
          isImportant: true,
        ),
      ]);

      expect(cardHeight(tester, 5), cardHeight(tester, 4));
    });

    testWidgets('"중요" 글자는 더 이상 목록에 없다', (tester) async {
      await pump(tester, const [
        CalendarEvent(
          id: 6,
          title: '중요 일정',
          eventDate: '2026-03-02',
          isImportant: true,
        ),
      ]);

      expect(find.text('중요'), findsNothing);
    });
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/calendar/event_list_kind_test.dart`
Expected: FAIL — `KindBadge`가 목록에 없어 `findsNWidgets(2)` 실패, `find.text('중요')` 1개 발견

- [ ] **Step 3: 제목 줄을 배지 + ★ + 제목 Row로 교체**

`event_list_section.dart` 상단 import에 추가:

```dart
import '../../../schedule/presentation/widgets/kind_badge.dart';
```

`_buildEventTile`의 카드 `Container`(183행, `padding: const EdgeInsets.all(AppSizes.cardPadding)`
바로 위)에 높이 측정을 위한 key를 준다 — 기존 `event_accent_bar_$id`와 같은 방식이다:

```dart
        child: Container(
          key: Key('event_card_${event.id}'),
          padding: const EdgeInsets.all(AppSizes.cardPadding),
```

209-229행 — `Expanded(child: Column(...))` 안의
`if (showImportant) _buildImportantBadge(event),` 와 그 아래 제목 `Text(...)` 두 항목을
다음 **한 개의 Row**로 교체한다 (설명 `Padding` 블록은 그대로 둔다):

```dart
                    Row(
                      children: [
                        KindBadge(kind: event.kind),
                        const SizedBox(width: AppSizes.spacing8),
                        if (showImportant) ...[
                          Semantics(
                            label: CalendarStrings.importantBadge,
                            child: Icon(
                              Icons.star_rounded,
                              key: Key('event_important_badge_${event.id}'),
                              size: 16,
                              color: AppColors.gold,
                            ),
                          ),
                          const SizedBox(width: AppSizes.spacing4),
                        ],
                        Expanded(
                          child: Text(
                            event.title,
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: titleColor,
                              decoration: isDone
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              decorationColor: AppColors.faint,
                              decorationThickness: 2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
```

- [ ] **Step 4: 배지 줄 위젯 제거**

305-316행의 `_buildImportantBadge` 메서드 전체(주석 포함)를 **삭제**한다.
`_goldPill`은 연도 배지가 계속 쓰므로 **남긴다**.

- [ ] **Step 5: 통과 확인**

Run: `flutter test test/features/calendar/event_list_kind_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 6: 기존 중요 테스트를 새 동작에 맞게 수정**

`test/features/calendar/event_list_important_test.dart:45` — 테스트 이름과 본문을 고친다.
(**삭제하지 말 것** — 레일 색 검증이 계속 필요하다)

```dart
    testWidgets('중요 이벤트는 ★ 아이콘 + 골드 레일', (tester) async {
      await pump(tester, const [
        CalendarEvent(
          id: 1,
          title: '시업식',
          eventDate: '2026-03-02',
          isImportant: true,
        ),
      ]);

      // 배지 줄이 아니라 제목 앞 인라인 ★ 아이콘 (같은 key 유지)
      expect(find.byKey(const Key('event_important_badge_1')), findsOneWidget);
      expect(find.text('중요'), findsNothing);
      expect(railColor(tester, 1), AppColors.gold);
    });
```

나머지 두 테스트(일반 이벤트 / 완료된 중요 이벤트)는 `findsNothing` 검증이라 그대로 통과한다.

- [ ] **Step 7: E2E 수정**

`integration_test/app_test.dart:348-349`의

```dart
      // 목록에 ★ 중요 배지 노출
      expect(find.text(CalendarStrings.importantBadge), findsOneWidget);
```

를 다음으로 교체한다:

```dart
      // 목록에 ★ 아이콘 노출 (글자 없는 인라인 표시).
      // 격자 셀도 같은 아이콘을 쓰므로 목록 섹션 안으로 한정한다.
      expect(
        find.descendant(
          of: find.byType(EventListSection),
          matching: find.byIcon(Icons.star_rounded),
        ),
        findsOneWidget,
      );
```

같은 파일 상단 import에 다음이 없으면 추가한다:

```dart
import 'package:planroutine/features/calendar/presentation/widgets/event_list_section.dart';
```

- [ ] **Step 8: 회귀 확인**

Run: `flutter analyze && flutter test`
Expected: analyze 경고 0 / 전체 통과

- [ ] **Step 9: 시뮬레이터로 실제 동작 확인**

Run: `flutter run -d "iPhone 16 Pro"` (또는 사용 가능한 시뮬레이터)
확인할 것:
1. 캘린더 탭 FAB → 시트에 `종류` 세그먼트 + `중요 표시`가 한 테두리에 보인다
2. `종료 날짜` 타일이 없고 설명칸이 4줄 높이로 열린다
3. `학교일정`으로 저장 → 캘린더 목록에 `일정` 배지가 붙고, **오늘 탭에는 안 뜬다**
4. 오늘 탭 FAB → 종류 행이 없고 카드에 `중요 표시`만 보인다
5. 중요 표시를 켠 항목과 안 켠 항목의 목록 행 높이가 같다

- [ ] **Step 10: 커밋**

```bash
git add lib/features/calendar/presentation/widgets/event_list_section.dart \
        test/features/calendar/event_list_kind_test.dart \
        test/features/calendar/event_list_important_test.dart \
        integration_test/app_test.dart
git commit -m "feat(calendar): 목록에 종류 배지 + 중요 배지 줄을 ★ 인라인으로"
```

---

## 마무리

- [ ] **CLAUDE.md 갱신** — "입력 탭 구조"·"업무 / 학교일정" 섹션에 다음을 반영한다:
  - 캘린더 시트에서 종류를 고를 수 있다(오늘 탭은 업무 고정)
  - 캘린더 목록 행에 종류 배지 + ★ 인라인
  - 종료 날짜 입력 제거(컬럼·Google 내보내기는 유지)
  - `_buildEvent()`는 copyWith여야 한다는 규칙
- [ ] **`document-release` 스킬로 옵시디언 작업 로그 작성**
- [ ] 배포는 사용자 판단에 따름 (`/deploy`)
