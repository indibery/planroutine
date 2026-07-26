# 일정 추가/수정 시트 재편 — 종류 분리 · 종료일 제거 · 설명 확대 — 설계

## 개요
`EventEditDialog`에 **업무/학교일정 선택**을 넣고, **종료 날짜 타일을 제거**하고, **설명칸을
2줄 → 4~6줄**로 늘린다. 종류와 중요 표시는 폼 하단의 "성격 카드" 한 테두리로 묶는다(D안).

넣을 수 있게 되면 보여야 하므로, **캘린더 목록 행에도 종류 배지**를 단다(월 그리드 점은
그대로 둔다).

동시에 이 시트가 편집 저장 시 필드를 조용히 날리던 버그를 구조적으로 차단한다 —
`_buildEvent()`를 생성자 조립에서 `copyWith` 기반으로 바꾼다.

## 배경 — 왜 지금 필요한가

`_buildEvent()`(`event_edit_dialog.dart:428`)는 `CalendarEvent`를 **새로 생성**한다. 그래서
`toMap()`이 쓰는 컬럼 중 생성자에 안 적힌 것은 전부 `@Default`/`null`로 되돌아가고,
`CalendarRepository.updateEvent`가 그 값으로 DB를 덮는다.

| 유실 필드 | 편집 저장 후 벌어지는 일 |
|---|---|
| `kind` | 학교일정 → 업무. 오늘 탭에 운동회가 뜬다 |
| `googleEventId` | Google 연결 끊김 → 재저장 시 Google 캘린더에 **중복 이벤트** |
| `deviceEventId` | 기기 캘린더도 같은 중복 |

`completedAt`은 `toMap()`에 없어 update가 건드리지 않으므로 무사하다.

`calendar_screen.dart:289`의 "중복 방지: `googleEventId`가 있으면 update API 호출"이라는
방어는 한 번이라도 편집하면 무력화된다. `kind` 유실은 CLAUDE.md가 "승계 지점이 급소"라고
경고한 증상과 같지만, 승계가 아니라 **편집 경로에서** 발생한다. 특히 "이전 연도 자료" 배지
탭(`_onBumpYear`)이 이 경로를 정면으로 밟는다.

원인은 필드 하나를 빠뜨린 게 아니라 **패턴**이다. 생성자 조립을 유지하는 한 `CalendarEvent`에
필드를 추가할 때마다 재발한다.

## 레이아웃

```
        ▁▁▁▁
       일정 추가                 🗑
 ┌──────────────────────────┐
 │ 제목                     │
 └──────────────────────────┘
   [ 2025 → 2026 ]              ← 기존 연도 칩 (조건부)
 ┌──────────────────────────┐
 │ 설명                     │
 │                          │   minLines 4 / maxLines 6
 │                          │
 └──────────────────────────┘
 ┌──────────────────────────┐
 │ 날짜      2026년 7월 26일 📅│
 └──────────────────────────┘
 ┌──────────────────────────┐   ← 성격 카드
 │ 🏷 종류  [ 업무 ][학교일정]│      오늘 탭에선 이 행만 숨김
 │──────────────────────────│
 │ ★ 중요 표시         (  ●)│
 └──────────────────────────┘
 [ AI로 보내기 ]                 ← 기존 조건부 (편집 + aiEnabled)
 [   취소   ] [    저장    ]
```

- **종료 날짜 타일 삭제**: 48px + 간격 8px 회수. 설명 확대(+66px)와 상쇄해 순증 약 10px.
- **성격 카드**: 지금의 중요 토글 `Container`(border + radius12)를 그대로 두고 위에 종류 행과
  `Divider`를 얹는다. 새 컨테이너를 만들지 않는다.

## 종류 선택 UI

- `SegmentedSettingRow<EntryKind>`를 재사용한다. 아이콘 + 라벨 + 세그먼트 Row 구조가 그대로
  맞고, 골드 채움 규칙(`goldFill`/`onGold` — 라이트 테마 대비 8.37:1)이 그 위젯 한 곳에 있다.
- 이 위젯은 현재 `features/settings/presentation/widgets/`에 있다. 캘린더가 쓰게 되므로
  **`shared/widgets/segmented_setting_row.dart`로 이동**한다. 기존 사용처 2곳
  (`theme_mode_tile.dart:16`, `stamp_settings_tiles.dart:24`)은 import 경로만 바뀐다.
- 세그먼트 라벨은 `EntryKind.filterLabel`(`업무` / `학교일정`)을 쓴다. `label`은 `업무`/`일정`
  이라 나란히 두면 대비가 흐려진다 — `entry_kind.dart:27` 주석이 밝힌 두 라벨의 용도 구분에
  그대로 해당한다.
- 아이콘은 `Icons.label_outline`(분류). 선택에 따라 바꾸지 않는다.
- **중요 표시는 두 종류 모두에서 유지**한다. 캘린더 ★ 강조는 학교 행사에도 의미가 있다.

## 종류 상태와 잠금

- `_kind` 상태를 `widget.event?.kind ?? EntryKind.task`로 초기화한다.
- `EventEditDialog`에 `allowKindChange`(기본 `true`)를 추가한다. `false`면 종류 **행만** 숨기고
  `_kind` 상태는 살려둔다 → 오늘 탭에서 편집해도 원래 종류가 보존된다.
- 종류 행을 숨길 때는 그 아래 `Divider`도 함께 빼서, 성격 카드가 지금과 똑같은
  "중요 표시 스위치 하나"로 보이게 한다(구분선만 남으면 뭔가 잘린 것처럼 읽힌다).
- 호출부:
  - `today_screen.dart:75`(FAB 추가), `today_screen.dart:88`(본문 탭 편집) → `false`
  - `calendar_screen.dart:145, 159, 178` → 기본값(`true`)
- **오늘 탭에서 종류를 못 고르는 이유**: 오늘 탭은 업무만 담는 화면이다(`buildTodayView`가
  `showsInToday`로 거른다). 여기서 학교일정을 만들면 저장 직후 목록에서 사라져 "저장이
  안 됐나?"로 읽힌다. 학교일정을 넣는 자리는 캘린더 탭 하나로 모은다.

## `_buildEvent()` copyWith 전환

```dart
CalendarEvent _buildEvent() {
  final now = DateTime.now().toIso8601String();
  final existing = widget.event;
  if (existing != null) {
    // 편집: 사용자가 만질 수 있는 것만 덮고 나머지는 전부 보존한다.
    // 생성자로 새로 만들면 googleEventId·deviceEventId·kind가 조용히 날아간다.
    return existing.copyWith(
      title: _titleController.text.trim(),
      description: _trimmedDescription(),   // 비면 null (기존 규칙 유지)
      eventDate: formatDate(_eventDate),
      isImportant: _isImportant,
      kind: _kind,
      updatedAt: now,
    );
  }
  return CalendarEvent(
    title: _titleController.text.trim(),
    description: _trimmedDescription(),
    eventDate: formatDate(_eventDate),
    isAllDay: true, isImportant: _isImportant, kind: _kind,
    createdAt: now, updatedAt: now,
  );
}
```

- `endDate`는 UI에서 사라져도 편집 시 `copyWith`가 보존한다. 신규는 항상 `null`.
- `_endDate` 상태·`_buildDateRow`의 종료일 타일·`_pickDate(isStart:)` 분기를 제거하고
  날짜 선택은 단일 타일로 단순화한다.

## 종료일 제거의 근거와 영향

- `getEventsByDateRange`는 `event_date`만 조회한다(`calendar_repository.dart:153`). 격자·월
  목록 어디에도 기간 렌더링이 없어 **3일짜리 이벤트도 시작일 하루에만 점이 찍힌다.** 즉
  종료일은 지금도 앱 안에서 아무 일도 하지 않는다.
- 실효가 있는 곳은 Google/기기 캘린더 저장 시 기간 이벤트로 내보낼 때뿐이다
  (`calendar_screen.dart:305-338`, `google_calendar_service.dart:119-132`).
- **DB 컬럼·모델·내보내기 경로는 그대로 둔다.** UI 입력만 없앤다. 기존에 기간이 설정된
  이벤트는 값이 보존되고 Google로도 계속 기간으로 나간다.

## 문자열

- `CalendarStrings.eventEndDate`(`'종료 날짜'`) 제거 — 참조처는 이 시트 한 곳뿐이다.
- `CalendarStrings.kindLabel = '종류'` 추가.

## 캘린더 목록의 종류 구분

시트에서 종류를 고를 수 있게 해도, 목록에서 어느 쪽인지 안 보이면 "왜 오늘 탭에 떴지?"가
그대로 남는다. **월 그리드 점은 건드리지 않고**(색 규칙이 이미 포화) **목록 행에서만** 구분한다.

- 대상은 `event_list_section.dart`의 행 하나뿐이다. `MonthEventList`는 날짜별로
  `EventListSection`을 쌓기만 하므로(`month_event_list.dart:111`) 고칠 곳이 한 군데다.
- **제목 앞 인라인 배지**로 넣는다. 현재 행 구조는 이렇다:

```
[accent bar] ┌ [★ 중요]            ← 조건부, 제목 위 한 줄
             │ 제목                                  [연도 배지] [✓]
             └ 설명                                  ← 조건부
```

  중요 배지 줄에 얹으면 종류는 항상 있으므로 **모든 행에 줄이 하나씩 생겨** 세로가 커진다.
  제목 `Text`를 `Row`로 감싸고 앞에 배지를 두면 세로 증가가 없다.

```
[accent bar] ┌ [★ 중요]
             │ [업무] 제목                           [연도 배지] [✓]
             └ 설명
```

- **업무·학교일정 둘 다 배지를 단다.** 입력 탭 검토 목록(`schedule_tile.dart:93`)이 이미 둘 다
  달고 있어, 캘린더만 한쪽을 생략하면 같은 배지 체계를 두 규칙으로 배우게 된다.
- 스타일은 `schedule_tile._buildKindBadge`(`schedule_tile.dart:191`)와 동일 — 옅은 배경
  (alpha 0.15) + 진한 글씨 10px w700, 학교일정 `AppColors.info` / 업무 `AppColors.sub`.
  골드는 오늘·중요 전용이라 쓰지 않는다.
- 같은 배지가 두 파일에 생기므로 **`shared/widgets/kind_badge.dart`로 추출**하고 양쪽이
  공유한다(`SegmentedSettingRow` 이동과 같은 성격). 라벨은 `EntryKind.label`(`업무`/`일정`) —
  행마다 반복되는 자리라 짧은 쪽을 쓴다(`entry_kind.dart:24` 주석).

## 테스트

신규 `test/features/calendar/event_edit_dialog_kind_test.dart`
- 캘린더 경로(기본): 종류 행 노출 → `학교일정` 선택 → 저장 결과 `kind == EntryKind.event`
- 오늘 탭 경로(`allowKindChange: false`): 종류 행 미노출 + 저장 결과 `kind == EntryKind.task`
- 오늘 탭에서 기존 이벤트 편집: 종류 행이 없어도 `kind`가 보존된다
- **보존 가드**: `googleEventId`·`deviceEventId`·`endDate`·`kind`가 채워진 이벤트를 제목만
  고쳐 저장 → 넷 다 그대로. 이것이 재발 방지선이다
- `종료 날짜` 타일 부재 확인

기존 `event_edit_dialog_{important,year,ai}_test.dart` 3개는 종료일을 검증하지 않아 영향 없다.
`today_screen_test.dart:92`는 `EventEditDialog` 존재만 확인하므로 무관.

캘린더 목록 배지 — 기존 `event_list_section` 위젯 테스트에 추가
- 업무 이벤트 행에 `업무` 배지, 학교일정 행에 `일정` 배지가 보인다
- 중요 배지·연도 배지와 같은 행에 있어도 제목이 잘리지 않는다(overflow 없음)

## 범위 밖 (YAGNI)

- **월 그리드 점의 종류 구분** — 사용자 확인(2026-07-26): 점으로는 구분하지 않는다. 색 규칙이
  이미 포화 상태다(골드=오늘·중요, 빨강=공휴일·일요일, 파랑=토요일·이벤트). 구분은 목록에서만.
- 기간 이벤트의 앱 내 렌더링(여러 날에 걸친 표시).
- 기존 데이터 `kind` 백필 — v7 `DEFAULT 'task'`가 곧 제품 결정이다.

## 설계 근거

- **성격 카드(D안)**: 종류와 중요는 둘 다 "이 항목이 어떤 성격인가"를 정하는 값이라 한 테두리
  안에 묶이는 게 논리적이고, 기존 중요 토글 컨테이너를 재사용해 구조 변화가 가장 작다.
  대신 종류가 폼 하단에 오므로 **기본값이 사실상의 동작**이 된다 — 캘린더는 기존 동작·DB
  기본값과 같은 `업무`로 두고, 오늘 탭은 아예 잠근다.
- **copyWith 전환**: `kind`만 끼워 넣으면 다음 필드에서 세 번째로 재발한다. "재발한 함정은
  가드로 승격"이라는 규율대로, 보존 가드 테스트와 함께 원인을 구조적으로 없앤다.
- **종료일 제거**: 앱 안에서 하는 일이 없는데 세로 48px과 "이미 설정된 것처럼 보이는" 회색
  힌트 텍스트를 쓰고 있었다. 그 자리를 실제로 쓰이는 설명칸에 넘긴다.
