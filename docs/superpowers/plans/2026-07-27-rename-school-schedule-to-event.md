# `학교일정` → `행사` 용어 변경 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 항목 종류의 표시 이름을 `학교일정`에서 `행사`로 바꾸고, 그 결과 근거가 사라진 `EntryKind`의 두 라벨(`label`/`filterLabel`)을 하나로 합친다.

**Architecture:** 표시 계층만 바꾼다 — DB 값(`kind = 'task'`/`'event'`)·스키마·마이그레이션은 그대로다. `EntryKind.label`이 `ScheduleStrings`를 참조하게 만들어 문자열을 한 곳에 모으고, `filterLabel`은 제거해 모든 사용처를 `label`로 통일한다.

**Tech Stack:** Flutter 3.x / Dart, Riverpod, Freezed, flutter_test

**설계 스펙:** `docs/superpowers/specs/2026-07-27-rename-school-schedule-to-event-design.md`

## Global Constraints

- 상태 관리는 **Riverpod만** 사용한다. 다른 라이브러리 금지.
- **`lib/` 안에서는 `!` 강제 언래핑 금지.** (테스트 코드는 예외)
- 하드코딩 금지: 색은 `AppColors`, 크기는 `AppSizes`, 문자열은 `AppStrings` / 도메인별 `*Strings` 클래스.
- 파일명 snake_case, 클래스명 PascalCase, **한글 UI + 한글 주석**.
- **기존 테스트 삭제 금지.** 문구가 바뀌어 성립하지 않는 테스트는 **개정**한다.
- **DB 값은 절대 바꾸지 않는다.** `kind`는 계속 `'task'`/`'event'`다. 마이그레이션 없음.
- **AI 프롬프트 본문(`ai_schedule_parser.dart`의 `buildAiPhotoPrompt`)은 건드리지 않는다** —
  소스 문서(월간 일정표)를 설명하는 말이라 UI 용어와 청중이 다르다.
- **`category_label.dart`의 `학교행사`는 건드리지 않는다** — 에듀파인 실제 분류명이다.
- `docs/superpowers/specs/`·`plans/`의 **과거 문서는 손대지 않는다** — 그때의 결정 기록이다.
- **이 문서의 행 번호는 작업 시작 시점 원본 기준 참고값**이다. 위치는 항상 **인용된 코드 블록과
  심볼 이름으로** 찾는다.
- 각 Task 끝에 `flutter analyze`(경고 0) + `flutter test`(전부 통과)를 확인하고 커밋한다.

## File Structure

| 파일 | 책임 | Task |
|---|---|---|
| `lib/core/constants/strings/schedule_strings.dart` | `kindEvent` → `'행사'`, `bulkRegisterEvent` 문구 | 1·2 |
| `lib/features/schedule/domain/entry_kind.dart` | 라벨 하나로 통합, `ScheduleStrings` 참조 | 1 |
| `lib/features/schedule/domain/filter_summary.dart` | `filterLabel` → `label` | 1 |
| `lib/features/schedule/presentation/widgets/schedule_filter_bar.dart` | `filterLabel` → `label` (2곳) | 1 |
| `lib/features/calendar/presentation/widgets/event_edit_dialog.dart` | `filterLabel` → `label` (세그먼트) | 1 |
| `lib/core/constants/strings/import_strings.dart` | `aiTitle`·`heroTitle` 문구 | 2 |
| `test/features/schedule/presentation/schedule_screen_input_test.dart` | 하드코딩 리터럴 → 상수 참조 | 2 |
| `lib/**` 주석 · `test/**` 테스트 이름 · `CLAUDE.md` · 릴리즈 노트 | 용어 일관성 | 3 |

**Task 의존 관계:** 1 → 2 → 3. Task 1이 `filterLabel`을 없애므로 그 사용처를 같은 Task에서 모두 고쳐야 컴파일이 유지된다.

---

### Task 1: `EntryKind` 라벨 통합 + `행사` 문자열

`filterLabel`을 없애고 `label` 하나로 만든다. 필드를 지우는 순간 모든 사용처가 깨지므로 한 Task에서 함께 고친다.

**Files:**
- Modify: `lib/core/constants/strings/schedule_strings.dart` (`kindEvent`)
- Modify: `lib/features/schedule/domain/entry_kind.dart` (전체 재작성)
- Modify: `lib/features/schedule/domain/filter_summary.dart` (`:26`)
- Modify: `lib/features/schedule/presentation/widgets/schedule_filter_bar.dart` (`:237`, `:243`)
- Modify: `lib/features/calendar/presentation/widgets/event_edit_dialog.dart` (`:346`)
- Test: `test/features/schedule/domain/entry_kind_test.dart` (개정 + 신규 2건)
- Test: `test/features/schedule/kind_badge_test.dart` (기대값 개정)
- Test: `test/features/schedule/domain/filter_summary_test.dart` (기대값 개정)

**Interfaces:**
- Consumes: `ScheduleStrings.kindTask`(`'업무'`), `ScheduleStrings.kindEvent`
- Produces: `EntryKind.label` (`String`) — **`filterLabel`은 더 이상 없다.** Task 2·3은 이 이름만 쓴다.

- [ ] **Step 1: 실패하는 테스트 작성**

`test/features/schedule/domain/entry_kind_test.dart`의 `EntryKind 표시` 그룹에서,
기존 `'두 종류 모두 화면에 쓸 짧은 라벨이 있다'` 테스트의 **`reason`만** 새 근거로 바꾸고
(어서션은 그대로 — `행사`도 2글자라 통과한다), 그 아래에 신규 2건을 추가한다.

```dart
    test('두 종류 모두 화면에 쓸 짧은 라벨이 있다', () {
      for (final kind in EntryKind.values) {
        expect(kind.label, isNotEmpty);
        expect(kind.label.length, lessThanOrEqualTo(4),
            reason: '배지·필터 칩·요약 줄이 모두 이 하나를 쓰므로 짧아야 한다');
      }
    });

    test('라벨은 ScheduleStrings 한 곳에서 온다 — enum에 문자열을 박지 않는다', () {
      expect(EntryKind.task.label, ScheduleStrings.kindTask);
      expect(EntryKind.event.label, ScheduleStrings.kindEvent);
    });

    test('두 종류의 라벨이 서로 다르다 — 대비가 라벨 하나로 서야 한다', () {
      expect(EntryKind.task.label, isNot(EntryKind.event.label));
    });
```

파일 상단 import에 추가한다(아직 없다):

```dart
import 'package:planroutine/core/constants/app_strings.dart';
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/schedule/domain/entry_kind_test.dart`
Expected: FAIL — `EntryKind.event.label`이 `'일정'`인데 `ScheduleStrings.kindEvent`는 `'학교일정'`이라 두 번째 테스트가 실패

- [ ] **Step 3: 문자열 상수 변경**

`lib/core/constants/strings/schedule_strings.dart`에서 주석과 값을 함께 바꾼다.

```dart
  // 종류 (업무 / 행사)
  static const kindTask = '업무';
  static const kindEvent = '행사';
```

- [ ] **Step 4: `EntryKind` 재작성**

`lib/features/schedule/domain/entry_kind.dart` 전체를 다음으로 바꾼다.

```dart
import '../../../core/constants/app_strings.dart';

/// 업무 / 행사 구분.
///
/// 두 종류는 성격이 다르다. **업무**는 내가 처리해야 하는 일이라 완료 개념이 핵심이고,
/// 오늘 탭에 떠서 체크·도장 대상이 된다. **행사**는 학교에서 열리는 일이라
/// 참고 정보이고 캘린더에만 보인다 — "운동회를 완료했다"는 어색하기 때문이다.
///
/// 입력 경로가 종류를 결정한다:
///   - 작년 CSV(생산문서등록대장) → 업무
///   - 월간 일정표 사진(AI 변환) → 행사
enum EntryKind {
  /// 내가 처리할 일. 오늘 탭에 뜬다.
  task('task', ScheduleStrings.kindTask),

  /// 학교에서 열리는 일. 캘린더에만 보인다.
  event('event', ScheduleStrings.kindEvent);

  const EntryKind(this.dbValue, this.label);

  /// DB(`schedules.kind` / `calendar_events.kind`)에 저장되는 값.
  /// **표시 이름이 바뀌어도 이 값은 그대로다** — 용어 변경은 표시 계층만이다.
  final String dbValue;

  /// 화면에 쓰는 이름. 배지·필터 칩·요약 줄이 **모두 이 하나**를 쓴다.
  ///
  /// 예전에는 짧은 `label`(`일정`)과 긴 `filterLabel`(`학교일정`)로 나뉘어 있었다 —
  /// 짧은 쪽이 우산말 `일정`과 겹쳐 업무와의 대비가 약했기 때문이다. `행사`는 2글자로도
  /// 충분히 강해 그 분리가 필요 없어졌다.
  final String label;

  /// 오늘 탭에 나타나는 종류인지. 업무만 뜬다.
  bool get showsInToday => this == EntryKind.task;

  /// DB 값 → enum. 모르는 값·null은 업무로 폴백한다.
  ///
  /// v7 마이그레이션이 `DEFAULT 'task'`를 주므로 실무상 null은 없지만,
  /// 컬럼이 없던 시절 백업을 복원하는 경로가 있어 방어한다.
  static EntryKind fromValue(String? value) {
    return EntryKind.values.firstWhere(
      (k) => k.dbValue == value,
      orElse: () => EntryKind.task,
    );
  }
}
```

- [ ] **Step 5: `filterLabel` 사용처 3파일 4곳 교체**

`lib/features/schedule/domain/filter_summary.dart` — `if (kind != null) kind.filterLabel,` 을:

```dart
    if (kind != null) kind.label,
```

`lib/features/schedule/presentation/widgets/schedule_filter_bar.dart` — 두 `PillChip`:

```dart
            label: label(EntryKind.task.label, counts?.pendingTask),
```
```dart
            label: label(EntryKind.event.label, counts?.pendingEvent),
```

`lib/features/calendar/presentation/widgets/event_edit_dialog.dart` — 종류 세그먼트:

```dart
                        label: Text(k.label),
```

확인: `grep -rn "filterLabel" lib test integration_test` → **0건**이어야 한다.

- [ ] **Step 6: 기대값이 바뀐 기존 테스트 2건 개정**

`test/features/schedule/kind_badge_test.dart` — 두 번째 테스트의 이름과 기대 문자열:

```dart
    testWidgets('행사는 라벨 "행사" + 파랑 계열', (tester) async {
      await pump(tester, EntryKind.event);

      expect(find.text('행사'), findsOneWidget);
      expect(badgeTextColor(tester), AppColors.info);
    });
```

`test/features/schedule/domain/filter_summary_test.dart` — `학교일정`이 들어간 기대값:

```dart
      expect(summary(kind: EntryKind.event), '검토 대기 21 · 행사');
```

- [ ] **Step 7: 통과 확인**

Run: `flutter test test/features/schedule/`
Expected: PASS. `schedule_tile_kind_badge_test.dart`는 `EntryKind.*.label`을 참조하므로 값 변경에 자동 추종한다 — 수정 없이 통과해야 한다.

- [ ] **Step 8: 회귀 확인**

Run: `flutter analyze && flutter test`
Expected: analyze 경고 0 / 전체 통과

- [ ] **Step 9: 커밋**

```bash
git add lib/core/constants/strings/schedule_strings.dart \
        lib/features/schedule/domain/entry_kind.dart \
        lib/features/schedule/domain/filter_summary.dart \
        lib/features/schedule/presentation/widgets/schedule_filter_bar.dart \
        lib/features/calendar/presentation/widgets/event_edit_dialog.dart \
        test/features/schedule/domain/entry_kind_test.dart \
        test/features/schedule/kind_badge_test.dart \
        test/features/schedule/domain/filter_summary_test.dart
git commit -m "refactor(schedule): 종류 라벨을 행사로 바꾸고 label 하나로 합친다"
```

---

### Task 2: 나머지 표시 문자열 + 깨질 하드코딩 정리

사용자에게 보이는 나머지 문구를 바꾸고, 문자열 변경에 조용히 무의미해질 테스트를 상수 참조로 고친다.

**Files:**
- Modify: `lib/core/constants/strings/schedule_strings.dart` (`bulkRegisterEvent`)
- Modify: `lib/core/constants/strings/import_strings.dart` (`aiTitle`, `heroTitle`)
- Modify: `test/features/schedule/presentation/schedule_screen_input_test.dart` (`:124`)

**Interfaces:**
- Consumes: 없음
- Produces: 없음

- [ ] **Step 1: 깨질 하드코딩부터 고친다**

`test/features/schedule/presentation/schedule_screen_input_test.dart`의 이 줄:

```dart
      expect(find.textContaining('일괄 일정 등록'), findsNothing);
```

**이대로 두면 문자열을 바꿨을 때 실패하지 않고 조용히 무의미해진다** — 찾는 대상이 사라지므로
`findsNothing`이 항상 참이 된다. 상수를 참조하도록 바꾼다.

```dart
      expect(
        find.textContaining(ScheduleStrings.bulkRegisterEvent(1)),
        findsNothing,
      );
```

같은 파일 상단에 `ScheduleStrings` import가 이미 있다(`:114`가 쓰고 있다). 없으면 추가한다:

```dart
import 'package:planroutine/core/constants/app_strings.dart';
```

- [ ] **Step 2: 이 시점에 테스트가 통과하는지 확인**

Run: `flutter test test/features/schedule/presentation/schedule_screen_input_test.dart`
Expected: PASS — 아직 문자열을 안 바꿨으므로 동작이 같다. (이 단계는 리팩터링이 무해함을 확인하는 것이다.)

- [ ] **Step 3: 일괄 등록 pill 문구 변경**

`lib/core/constants/strings/schedule_strings.dart`:

```dart
  static String bulkRegisterEvent(int n) => '일괄 행사 등록 $n건';
```

- [ ] **Step 4: 사진 AI 히어로 문구 변경**

`lib/core/constants/strings/import_strings.dart`:

```dart
  static const aiTitle = '행사를 사진으로';
```
```dart
  static const heroTitle = '행사 사진으로 넣기';
```

- [ ] **Step 5: 통과 확인**

Run: `flutter test`
Expected: 전체 통과. Step 1에서 상수 참조로 바꿔뒀으므로 `schedule_screen_input_test.dart`가 새 문자열을 자동으로 따라간다.

- [ ] **Step 6: 회귀 확인**

Run: `flutter analyze && flutter test`
Expected: analyze 경고 0 / 전체 통과

확인: `grep -rn "일괄 일정 등록" lib test integration_test` → **0건**

- [ ] **Step 7: 커밋**

```bash
git add lib/core/constants/strings/schedule_strings.dart \
        lib/core/constants/strings/import_strings.dart \
        test/features/schedule/presentation/schedule_screen_input_test.dart
git commit -m "feat(schedule): 일괄 등록 pill·사진 AI 히어로 문구를 행사로"
```

---

### Task 3: 주석·테스트 이름·문서의 용어 통일

동작은 하나도 바뀌지 않는다. 코드가 쓰는 말과 주석·문서가 갈리지 않게 맞춘다.

**Files:**
- Modify: `lib/**`의 주석 — `grep -rn "학교일정" lib`로 찾는다
- Modify: `test/**`·`integration_test/**`의 테스트 이름·주석 — `grep -rn "학교일정" test integration_test`
- Modify: `CLAUDE.md` (용어 절, EntryKind 절, 핵심 기능 3번)
- Modify: `docs/release_notes/1.2.0.ko.txt` (1줄 추가)

**Interfaces:**
- Consumes: Task 1의 `EntryKind.label`(이름만 남음)
- Produces: 없음

- [ ] **Step 1: `lib/` 주석 치환**

`grep -rn "학교일정" lib`로 전부 찾아 `행사`로 바꾼다. **기계적 치환으로 문장이 어색해지면 다시 쓴다.**
예를 들어 이런 것들이다:

- `entry_kind.dart` — Task 1에서 이미 처리됨(재확인만)
- `today_view.dart` — `학교일정(운동회 등)에는 완료 개념이 없어` → `행사(운동회 등)에는 …`
- `calendar_repository.dart` — `끊기면 학교일정이 업무로 둔갑해` → `끊기면 행사가 업무로 둔갑해`
- `event_edit_dialog.dart` — `종류(업무/학교일정) 선택 행을 노출할지` → `종류(업무/행사) …`,
  `거기서 학교일정을 만들면` → `거기서 행사를 만들면`
- `kind_badge.dart` — `업무 / 학교일정 배지` → `업무 / 행사 배지`
- `schedule_filter_bar.dart` — `종류(업무/학교일정 토글)` → `종류(업무/행사 토글)`
- `ai_schedule_register.dart` — `AI가 사진에서 뽑은 학교일정을` → `… 뽑은 행사를`,
  `사진(월간 일정표) 경로는 학교일정` → `… 경로는 행사`
- `ai_schedule_parser.dart` — `AI가 사진에서 뽑아준 학교일정 한 건` → `… 행사 한 건`
- `import_strings.dart:6`·`import_screen.dart:19` — `학교일정 사진 AI는 입력 탭 히어로가 맡는다`
  → `행사 사진 AI는 …`
- `database_helper.dart`·`schedule_strings.dart`·`calendar_strings.dart`·
  `schedule_providers.dart`·`screenshot_seed.dart` — 같은 방식

**`buildAiPhotoPrompt`의 프롬프트 본문은 건드리지 않는다**(`학교 월간·연간 일정표`, `표에 있는
모든 일정` 등은 소스 문서 설명이다).

확인: `grep -rn "학교일정" lib` → **0건**(단, `buildAiPhotoPrompt` 본문에는 애초에 `학교일정`이
없으므로 이 확인과 충돌하지 않는다)

- [ ] **Step 2: 테스트 이름·주석 치환**

`grep -rn "학교일정" test integration_test`로 찾아 바꾼다. 전부 한글 서술이라 동작과 무관하다.
17개 파일이며, 예:

- `entry_kind_test.dart` — 파일 상단 doc comment와 `'업무는 task, 학교일정은 event로 저장된다'`
- `kind_propagation_test.dart` — `'학교일정을 확정하면 캘린더 이벤트도 학교일정이다'` 등
- `schedule_repository_kind_test.dart` — `'학교일정만 조회한다'` 등
- `database_helper_test.dart:152` — `'학교일정으로 지정해 넣으면 그대로 저장된다'`
- `integration_test/app_test.dart` — `:593`(테스트 이름)·`:622`(주석)·`:626`(`reason` 문구)

확인: `grep -rn "학교일정" test integration_test` → **0건**

- [ ] **Step 3: 테스트가 여전히 통과하는지 확인**

Run: `flutter test`
Expected: 전체 통과. 이름만 바뀌었으므로 건수가 그대로여야 한다.

- [ ] **Step 4: CLAUDE.md 용어 절 반전**

현재 「용어」 절은 정확히 두 줄이다(`CLAUDE.md:328-330`).

```markdown
### 용어
- **일정 / 학교일정 / 업무**만 쓴다. "행사"·"행사표"는 쓰지 않는다(AI 프롬프트 본문 포함).
- 예외: `category_label.dart`의 `학교행사`는 에듀파인 실제 분류명이라 그대로 둔다.
```

이 절을 통째로 다음으로 바꾼다.

```markdown
### 용어
- **일정 / 행사 / 업무**를 쓴다. `학교일정`은 쓰지 않는다 — `일정`이 우산말(시트 제목
  `일정 추가/수정`)이자 라벨의 절반이라 겹쳐 읽혔다(사용자 신고, 2026-07-27).
- **`행사`가 에듀파인 카테고리 `학교행사`와 안 부딪히는 이유**: 둘은 **같은 행에 나타날 수
  없다.** 카테고리 배지는 `schedule.category != null`일 때만 렌더되고(`schedule_tile.dart`),
  `category`를 채우는 것은 CSV 경로(`createFromImported`·`createBulkFromImported`)뿐이며
  그 경로는 항상 업무다. 사진 AI 경로(= 행사)는 `registerAiSchedules`가 `category`를 넣지
  않는다. 캘린더 목록에는 카테고리 배지 자체가 없다.
  (이전에는 이 혼동을 걱정해 "행사" 사용을 금지했었다 — 근거를 확인하고 뒤집었다.)
- 예외 둘:
  - `category_label.dart`의 `학교행사` — 에듀파인 실제 분류명이라 그대로 둔다.
  - **AI 프롬프트 본문**(`ai_schedule_parser.dart`의 `buildAiPhotoPrompt`) — `학교 월간·연간
    일정표`처럼 **소스 문서를 설명하는 말**이라 UI 용어와 청중이 다르다. 우리 분류에 맞춰
    고치면 추출 품질이 흔들릴 수 있어 건드리지 않는다.
```

- [ ] **Step 5: CLAUDE.md 나머지 갱신**

- 「업무 / 학교일정 (EntryKind)」 **절 제목**을 「업무 / 행사 (EntryKind)」로, 본문의 `학교일정`을
  `행사`로.
- 그 절의 라벨 설명을 갱신: `EntryKind`는 이제 **라벨이 하나**(`label`)이고 `ScheduleStrings`를
  참조한다. 예전 `label`/`filterLabel` 분리는 짧은 `일정`이 우산말과 겹쳐 약했기 때문인데,
  `행사`로 바뀌며 근거가 사라져 합쳤다.
- 핵심 기능 3번 `**업무 / 학교일정 구분**` → `**업무 / 행사 구분**`, 본문의 `학교일정`도.
- 「입력 탭 구조」·「일정 추가/수정 시트」 등 다른 절에 남은 `학교일정`도 함께.

확인: `grep -n "학교일정" CLAUDE.md` → **0건**

- [ ] **Step 6: 릴리즈 노트 1줄 추가**

`docs/release_notes/1.2.0.ko.txt`의 맨 아래 버그 수정 줄 **앞**에 사용자 언어로 추가한다.
기존 `• ` 톤을 따른다. 이미 출하된 과거 줄은 고치지 않는다.

```
• '학교일정'이라는 이름을 '행사'로 바꿨습니다. 일정을 수정할 때 이름이 겹쳐 헷갈리던 것을 없앴습니다.
```

- [ ] **Step 7: 회귀 확인**

Run: `flutter analyze && flutter test`
Expected: analyze 경고 0 / 전체 통과

- [ ] **Step 8: 커밋**

```bash
git add -A lib test integration_test CLAUDE.md docs/release_notes/1.2.0.ko.txt
git commit -m "docs: 주석·테스트 이름·CLAUDE.md의 용어를 행사로 통일

CLAUDE.md의 '행사 금지' 규칙을 뒤집되 왜 안전한지를 함께 남긴다 — 우려였던
에듀파인 학교행사 카테고리와의 혼동은 구조적으로 불가능하다."
```

---

## 마무리

- [ ] **시뮬레이터 확인** (컨트롤러가 수행)
  1. 입력 탭 필터 줄: `[업무] [행사]` 칩
  2. 검토 목록 행 배지: `[업무]` / `[행사]`
  3. 하단 일괄 등록 pill: `일괄 행사 등록 N건`
  4. 캘린더 시트 성격 카드: `종류 [업무][행사]`
  5. 캘린더 목록 배지: `[행사]`
  6. 입력 탭 히어로 제목: `행사 사진으로 넣기`
- [ ] **`document-release` 스킬로 옵시디언 작업 로그 작성**
- [ ] 배포는 사용자 판단에 따름
