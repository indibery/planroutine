# 연도 칩 1회용 + `작년` 배지 저장 시 해제 — 설계

## 개요

두 가지를 고친다. 둘은 **하나의 상태**를 공유한다.

1. **연도 칩이 여러 번 눌린다** — 누를 때마다 연도가 계속 올라간다. 한 번 밀면 끝나야 한다.
2. **`작년` 배지가 영구적이다** — 작년 항목을 수정해 날짜를 옮기면 그건 이제 올해 일정인데, 배지가 그대로 남는다. 저장하면 사라져야 한다.

`calendar_events.reviewed_at`(DB v8) 하나로 둘을 끈다. **저장이 유일한 기준**이다 —
저장하면 칩과 배지가 함께 영구히 꺼지고, 취소하면 아무것도 바뀌지 않아 다시 나타난다.

## 배경 — 왜 지금 이 모양인가

직전 작업에서 `작년` 배지를 **출처 표시**로 설계했다. 판정 기준이 `schedules.source_id != null`
하나라 상태가 없고, 그래서 지울 방법도 없었다. 그 결정의 대가를 당시 스펙에 이렇게 적어뒀다.

> 목록에서 "아직 제목이 옛 연도인 항목"을 찾을 수단이 없다. 예전 골드 배지가 그 색인이었다.

이번 변경이 그 부채를 갚는다. 배지가 **출처 표시에서 할 일 표시로** 바뀌면서, 남아 있는
배지가 곧 "아직 정리 안 한 목록"이 된다. 색인이 돌아온다.

**정정(2026-07-27)**: 위 문단은 배지의 범위를 과대 주장했다. `reviewed_at`은 연도를 고쳤는지와
무관하게 **편집 시트의 모든 저장에서** 기록된다(중요 스위치만 바꿔도, 날짜만 옮겨도 기록된다) —
연도 없는 제목(`종업식 및 졸업식 학사일정변경 안내장`)의 배지를 지울 방법을 남겨두기 위한
의도된 설계다(§5 참고). 그래서 실제로 돌아온 것은 **"아직 검토(열어서 저장)하지 않은 항목"**
색인이지, **"아직 제목이 옛 연도인 항목"** 색인이 아니다. 두 집합은 다르다 — 날짜만 옮기고
저장하면 제목이 여전히 2025여도 배지는 꺼진다. 연도 자체를 확인할 수 있는 곳은 배지가 아니라
**개별 항목의 편집 칩 하나뿐**이다. 직전 작업이 남긴 부채("아직 옛 연도인 항목을 찾을 수 없다")는
이번 변경으로 **근사치로만** 갚였다.

연도 칩도 같은 뿌리다. `shiftTitleYears`가 상대 기준(+1년)이라 "이제 됐다"는 종료 조건이
함수 안에 없다. 종료 조건은 **사용자의 행동**(저장)에만 있다.

## 왜 `updated_at`으로는 안 되는가

"수정된 적 있나"를 기존 컬럼으로 판단하려 했으나 막혔다.
`CalendarRepository._updateExternalEventId`(`:71-83`)가 `updated_at`을 함께 쓴다.

```dart
{column: externalId, 'updated_at': DateTime.now().toIso8601String()},
```

그래서 Google/기기 캘린더 저장 스와이프만 해도 `updated_at`이 바뀐다 — 제목은 아직 2025인데
배지가 사라진다. 전용 컬럼이 필요하다.

반대로 좋은 사실도 있다: **`toMap()`을 쓰는 쓰기 경로는 `updateEvent` 하나뿐**이다
(`createEvent`는 신규, 나머지 `markCompleted`·`markIncomplete`·`_updateExternalEventId`·
`deleteEvent`·`restoreEvent`는 각자 컬럼만 쓴다). 새 컬럼을 `toMap()`에 넣으면
**편집 시트 저장에서만** 기록된다 — 스와이프로 지워지는 일이 구조적으로 불가능하다.

## 1. DB v8 — `reviewed_at`

```
calendar_events.reviewed_at TEXT   -- NULL = 아직 손대지 않음
```

- `_databaseVersion` 7 → 8
- `_onUpgrade`에 `oldVersion < 8` 블록: `ALTER TABLE $tableCalendarEvents ADD COLUMN reviewed_at TEXT`
- `_onCreate`의 `calendar_events` 정의에 `reviewed_at TEXT` 추가 (`kind` 다음 줄)
- **기존 행은 NULL** — 배지·칩이 유지된다. 아직 검토하지 않은 게 맞다. 백필하지 않는다.
- `schedules`에는 추가하지 않는다. 이건 캘린더 이벤트의 검토 상태다.

**이름의 뜻**: "사용자가 편집 시트에서 저장해 이 항목을 검토·정리한 시각". 무엇을 정리했는지
(연도를 밀었는지, 보고 그냥 뒀는지)는 구분하지 않는다 — 저장했다는 것 자체가 검토의 증거다.

## 2. 모델

`CalendarEvent`에 실제 컬럼 필드를 추가한다.

```dart
@JsonKey(name: 'reviewed_at') String? reviewedAt,
```

- `fromMap`: `reviewedAt: map['reviewed_at'] as String?`
- **`toMap()`에 넣는다** — `'reviewed_at': reviewedAt`. 파생 필드인 `fromImport`와 반대다.
- 판정 getter를 추가한다(기존 `showsImportant`와 같은 패턴):

```dart
/// 목록에 `작년` 배지를 노출할지. 가져온 자료이면서 아직 검토하지 않은 것만.
/// 검토(편집 시트 저장)하면 꺼져, 남아 있는 배지가 곧 할 일 목록이 된다.
bool get showsImportBadge => fromImport && reviewedAt == null;
```

## 3. 목록 배지

`event_list_section._buildImportBadge`의 조건을 바꾼다.

```dart
if (!event.showsImportBadge) return const SizedBox.shrink();
```

모양·위치·문구(`작년`, 테두리형, 행 오른쪽)는 그대로다.

## 4. 연도 칩 — 두 장치

칩이 꺼지는 이유가 두 가지이고, 사는 곳도 다르다.

```dart
Widget _buildYearShiftChip() {
  // 수정 경로 전용(직전 작업) + 이미 정리된 항목이면 안 뜬다.
  if (!_isEditing || widget.event?.reviewedAt != null) {
    return const SizedBox.shrink();
  }
  // 이 시트에서 이미 눌렀으면 안 뜬다 — 여러 번 눌러 연도가 계속 올라가는 것을 막는다.
  if (_yearShifted) return const SizedBox.shrink();
  return ValueListenableBuilder<TextEditingValue>( ... );
}
```

- `bool _yearShifted = false;` 상태 추가. 칩의 `onPressed`에서 제목을 밀고
  `setState(() => _yearShifted = true)`.
- **세션 플래그는 저장하지 않는다.** 취소하면 사라지므로 다시 열면 칩이 돌아온다.

| 장치 | 막는 것 | 수명 |
|---|---|---|
| `_yearShifted` (상태) | 이 시트에서 두 번 누르기 | 시트 세션 |
| `reviewed_at` (컬럼) | 이미 정리한 항목에 다시 권하기 | 영구 |

## 5. 저장 경로

`EventEditDialog._buildEvent()`의 **편집 분기에만** 추가한다.

```dart
return existing.copyWith(
  ...
  reviewedAt: now,
  updatedAt: now,
);
```

- 신규 생성 분기는 건드리지 않는다 — 생성 시점에 검토란 개념이 없다(`null`로 남는다).
- **`copyWith` 계약을 지킨다**: `reviewedAt`은 사용자 행동으로 바뀌는 값이라 명시하는 게 맞다.
  `kind`·`googleEventId`·`deviceEventId`·`color`·`scheduleId`·`createdAt`·`completedAt`은
  계속 **적지 않는다**(적지 않아야 보존된다).
- 칩을 눌렀든 안 눌렀든 저장하면 기록된다. 열어보고 "고칠 게 없다"고 판단한 것도 검토다 —
  조건을 "칩을 눌렀을 때만"으로 하면 연도 없는 제목(`종업식 및 졸업식 …`)의 배지를 지울
  방법이 영원히 없다.

## 흐름

```
작년 항목 열기        →  [⟳ 2025 → 2026] 칩 있음
칩 탭                →  제목 바뀌고 칩 사라짐          (_yearShifted)
저장                 →  reviewed_at 기록
다시 열기            →  칩 없음, 목록에 작년 배지도 없음

칩 탭 → 취소         →  아무것도 저장 안 됨
다시 열기            →  칩 다시 있음, 배지도 그대로
```

## 안 바뀌는 것

- 배지는 누를 수 없다(표시일 뿐). 편집 진입은 행 탭.
- 판정의 `schedules.source_id` LEFT JOIN, 에듀파인 CSV 경로 한정.
- `shiftTitleYears(title, {by = 1})` 규칙, 칩 라벨 규칙(1개면 `2025 → 2026`, 2개 이상이면
  `연도 모두 +1년`).
- 완료 토글·Google/기기 저장은 `reviewed_at`을 건드리지 않는다.
- 오늘 탭에는 `작년` 배지가 없다(직전 작업의 범위 결정).

## 테스트

**마이그레이션** — `test/core/database/database_helper_test.dart`에 `마이그레이션 v7 → v8 (reviewed_at)`
그룹을 추가한다. 같은 파일의 `마이그레이션 v5 → v6 (is_important)`(`:25`)·`v6 → v7 (kind)`(`:108`)
그룹이 이미 쓰는 패턴을 따른다(옛 버전 스키마를 손으로 만들고 행을 넣은 뒤 업그레이드해 확인).
- `calendar_events`에 `reviewed_at` 컬럼이 존재한다
- **v7 DB의 기존 행은 업그레이드 후 `reviewed_at`이 NULL이다** — 배지·칩이 유지되는 근거

**모델**
- `fromMap`/`toMap` 라운드트립에 `reviewed_at`이 살아남는다
- `showsImportBadge`: `fromImport=true, reviewedAt=null` → true / `reviewedAt` 있으면 false /
  `fromImport=false`면 항상 false

**목록 배지** (`event_list_import_badge_test.dart` 개정)
- `fromImport=true, reviewedAt=null` → `작년` 배지
- `fromImport=true, reviewedAt` 있음 → **배지 없음**
- 손입력(`fromImport=false`) → 배지 없음 (기존 테스트 유지)

**연도 칩** (`event_edit_dialog_year_test.dart` 개정)
- `reviewedAt=null`인 기존 이벤트: 칩 노출
- **`reviewedAt` 있는 기존 이벤트: 칩 미노출**
- **칩을 한 번 탭하면 칩이 사라진다** (기존 "두 번 탭하면 두 해 밀린다" 테스트는 이 동작으로
  **개정**한다 — 두 번 누르기가 이제 불가능하다)
- 신규 생성 경로: 칩 미노출 (기존 테스트 유지)

**저장 경로** (`event_edit_dialog_preserve_test.dart` 개정/추가)
- 편집 저장 결과에 `reviewedAt`이 채워진다
- 칩을 누르지 않고 저장해도 `reviewedAt`이 채워진다
- **기존 보존 가드는 그대로 통과해야 한다** — `kind`·`googleEventId`·`deviceEventId`·`endDate`

**리포지토리**
- `markCompleted`·`updateGoogleEventId`는 `reviewed_at`을 바꾸지 않는다 (스와이프로 배지가
  지워지지 않음을 고정하는 가드)

## 범위 밖 (YAGNI)

- 기존 데이터 백필 — NULL이 곧 "아직 안 봄"이라 맞는 상태다.
- `작년` 배지를 눌러 바로 해제하기 — 배지는 표시이고 해제는 검토의 결과다.
- 검토 시각을 UI에 보여주기.
- `schedules` 쪽 검토 상태(입력 탭 검토 목록) — 그쪽은 `status`가 이미 관문이다.
- 칩을 누른 것과 그냥 저장한 것을 구분해 기록하기 — 지금 쓸 데가 없다.

## 설계 근거

- **저장을 유일한 기준으로 삼은 것**이 핵심이다. 칩 탭만으로 영구 기록하면 실수로 누른 것을
  되돌릴 수 없고, 취소해도 남는다. 저장 기준이면 "취소하면 원상복구"가 공짜로 따라온다.
- **두 장치를 나눈 이유**: 세션 플래그와 컬럼은 막는 대상이 다르다. 하나로 합치려면 칩 탭마다
  DB를 쓰거나(취소 복구 불가), 아니면 두 번 누르기를 허용해야 한다(원래 버그).
- **`toMap()`을 쓰는 경로가 하나뿐이라는 사실에 기댄다.** 이게 "스와이프로는 안 지워진다"를
  규율이 아니라 구조로 만든다. 새 컬럼을 다른 곳에서 쓰려면 그 메서드를 고쳐야 하고, 그때
  이 결정을 다시 마주하게 된다.
- **배지의 의미가 바뀐 것을 문서에 남긴다.** 출처 표시(`source_id`만 봄)에서 할 일 표시
  (`source_id` + `reviewed_at`)로 옮겨간 것이라, CLAUDE.md의 "작년 배지" 항목을 함께 고친다.
