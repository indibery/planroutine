# 지도 기록 편집 화면 B안 정리표 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 지도 기록 편집 화면(새 기록·기록 수정)을 제목 → 정리표 카드 → 첨부 버튼 → 경과 → 펼치는 들은 말·판단·조치 순서로 바꾼다. 저장값·동작은 그대로다.

**Architecture:** `guidance_edit_screen.dart`의 `ListView` 자식 배치만 바꾼다. 사건 시각은 새 위젯 `OccurredRow`(요약 한 줄 + 누르면 시트, 시트 안에서 기존 `OccurredInput`을 즉시 반영으로 재사용)로 감싼다. 안내문 둘은 ⓘ `IconButton` → `useRootNavigator: false` 대화상자.

**Tech Stack:** Flutter 3.44.8, flutter_riverpod 2.6.x.

**Spec:** `docs/superpowers/specs/2026-11-03-guidance-edit-layout-b-design.md`

## Global Constraints

- 배치만 바꾼다: `GuidanceContent`·판·잠금·첨부·녹음 흐름·`?record=1` 무변경. 배치 변경만으로 dirty가 되거나 판이 생기면 실패.
- 기존 키 유지: `GuidanceEditScreen.saveKey, cancelKey, titleKey, placeKey, factsKey, quotesKey, actionsKey, recordKey, importAudioKey, importImageKey, retryAttachKey, kindKey(k), statusKey(s)` + `OccurredInput.*Key` + `ParticipantChipsField.*Key`.
- 새 키: `GuidanceEditScreen.kindInfoKey`, `participantsInfoKey`, `addQuotesKey`, `addActionsKey`; `OccurredRow.rowKey`.
- 새 문자열(`GuidanceStrings`, 기존 상수는 바꾸지 않는다): `labelStatusShort='상태'`, `labelWhen='언제'`, `labelWhere='어디서'`, `labelWho='누가'`, `recordShort='녹음'`, `importImageShort='사진'`, `importAudioShort='녹음 파일'`, `kindInfoLabel='구분 안내'`, `participantsInfoLabel='관련인 안내'`.
- 320pt·390pt 넘침 없음. 정리표 행 이름은 `AppTextStyles.fieldLabel`(14pt).
- 가드 준수: `SegmentedButton`은 `showSelectedIcon: false`, `TextField`는 이름(`labelText`/`hintText`/`Semantics`), `InkWell`/`GestureDetector`는 `ButtonSemantics`, `IconButton`은 `Icon(semanticLabel:)`, tooltip 금지, 대화상자·시트 `useRootNavigator: false`, 날짜·시각은 `PickerFieldTile`.
- 기존 테스트 선언은 지우지 않는다. 기대값이 바뀌면 단계(시트 열기·ⓘ 누르기·펼치기)를 더해 고친다.

## Review Focus

1. 기록 수정에서 들은 말에 내용이 있는데 접힌 채 열림(`_load` 비동기) → Task 3 테스트.
2. 언제 시트에서 대략 글을 쓰고 끌어서 닫은 뒤 저장 → 글이 저장된다 → Task 1 테스트.
3. 320pt에서 구분 칩 `교육활동 침해` + ⓘ가 넘침 → Task 2 테스트.
4. 새 기록을 열고 아무것도 안 한 채 취소 → 확인 창 없이 나간다(배치 변경으로 dirty 아님) → Task 2 테스트.
5. `녹음으로 새 기록`(`startRecording`) 진입 → 녹음 화면이 그대로 뜬다 → 기존 첨부 테스트 유지 확인(Task 3).

---

### Task 1: `OccurredRow` — 요약 한 줄 + 시트

**Files:**
- Create: `lib/features/guidance/presentation/widgets/occurred_row.dart`
- Modify: `lib/core/constants/strings/guidance_strings.dart` (이 작업에서 Global Constraints의 새 문자열 9개를 모두 추가)
- Test: `test/features/guidance/presentation/occurred_row_test.dart`

**Interfaces:**
- Produces: `class OccurredRow extends StatelessWidget` — `OccurredRow({required GuidanceContent current, required DateTime now, required String createdLine, required OccurredPrecision precision, required DateTime occurredAt, required String? occurredText, required ValueChanged<OccurredPrecision> onPrecision, required ValueChanged<DateTime> onAt, required ValueChanged<String> onText})`, `static const rowKey`. `current`는 요약용(`formatOccurred(current, now:)`), 나머지는 `OccurredInput`에 그대로 넘기는 값과 콜백. 왼쪽 `GuidanceStrings.labelWhen`(fieldLabel), 가운데 요약, 오른쪽 `precision.label` + chevron. 누르면 `showModalBottomSheet(useRootNavigator: false)`, 시트 = `SheetTitle(labelOccurred)` + `OccurredInput`(즉시 반영 — 시트 내부 상태로 다시 그리고 매 변경을 콜백으로 올림) + `createdLine` 한 줄(bodyS, sub).
- `OccurredInput`의 생성자 시그니처는 읽어서 그대로 맞춘다(바꾸지 않는다).

- [ ] **Step 1: 테스트** — (a) 요약이 `formatOccurred` 값, 오른쪽 `정확히` 표시. (b) 행 누르기 → 시트에 `OccurredInput` 세그먼트와 `createdLine`. (c) 시트에서 `날짜만` → 콜백 `onPrecision(date)` 1회, 시트 안 선택이 즉시 바뀜. (d) `대략` → 글 입력 → 시트를 아래로 끌어 닫음 → `onText`가 마지막 글로 불렸다. (e) 대략 + 빈 글 요약은 `occurredUnknown`. (f) 320pt 넘침 없음. (g) `useRootNavigator: false` 가드 테스트(`guidance_root_navigator_guard_test`) 통과.
- [ ] **Step 2: FAIL 확인** — `flutter test test/features/guidance/presentation/occurred_row_test.dart`
- [ ] **Step 3: 구현**
- [ ] **Step 4: 통과 + `flutter test test/features/guidance test/shared` + `flutter analyze`**
- [ ] **Step 5: 커밋** — `feat(guidance): 사건 시각 요약 한 줄과 시트(OccurredRow)`

### Task 2: 제목 + 정리표 카드 + ⓘ

**Files:**
- Modify: `lib/features/guidance/presentation/screens/guidance_edit_screen.dart`
- Modify (기대값): `test/features/guidance/presentation/guidance_edit_screen_test.dart`, 그 밖에 깨지는 지도 기록 테스트
- Test: `test/features/guidance/presentation/guidance_edit_layout_test.dart`

**Interfaces:**
- Consumes: Task 1 `OccurredRow`, 새 문자열.
- Produces: 화면 상단 = 제목 입력(라벨 줄 없음, 20pt w700, `Semantics(label: labelTitle)` 유지, 골드 밑줄) → 정리표 카드(`Material` 흰 바탕·`AppColors.border` 테두리·`radius14`, 행 사이 구분선). 행: `구분`(PillChip 둘 + 끝 ⓘ `kindInfoKey`) · `labelStatusShort`(PillChip 셋) · `OccurredRow` · `labelWhere`(테두리 없는 `TextField`, `placeKey`, `hintText` 있음) · `labelWho`(`ParticipantChipsField` + 끝 ⓘ `participantsInfoKey`). 행 이름 폭 고정(구현자 판단, 52~60), 값은 `Wrap`. ⓘ = `IconButton(icon: Icon(Icons.info_outline, semanticLabel: kindInfoLabel/participantsInfoLabel))` → `ConfirmDialog`가 아닌 단순 대화상자(`showDialog(useRootNavigator: false)`)에 `scopeNote`/`participantsHint`. 화면에서 `scopeNote`·`participantsHint`·기존 `_hint` 줄·`기록 시각` 줄 제거(기록 시각은 Task 1 시트로 이동).

- [ ] **Step 1: 새 레이아웃 테스트** — (a) 제목 dy < 정리표(구분 행) dy. (b) `scopeNote`·`participantsHint` 화면에 없음 → `kindInfoKey` 누르면 `scopeNote`, `participantsInfoKey` 누르면 `participantsHint`. (c) `kindKey(GuidanceKind.infringement)`·`statusKey(GuidanceStatus.closedAtSchool)` 누르면 저장값 반영(저장 후 판의 kind/status). (d) 새 기록을 열고 취소 → 확인 창 없음. (e) 320·390pt 넘침 없음(구분 행 포함). (f) 정리표 행 이름 14pt.
- [ ] **Step 2: FAIL 확인**
- [ ] **Step 3: 구현**
- [ ] **Step 4: 기존 테스트 기대값 고치기** — `구분 바로 아래에 범위 안내가 보인다` → ⓘ 누르면 보인다. `관련인·들은 말·판단·조치 안내 문구가 보인다` → participantsHint는 ⓘ, createdOnSave는 언제 시트(quotes/actions는 Task 3에서 마저). 정밀도·날짜 키를 바로 누르던 테스트 → `OccurredRow.rowKey` 먼저 누름. `14pt` 테스트 → 정리표 행 이름. 선언 수 유지.
- [ ] **Step 5: `flutter test test/features/guidance test/shared` + `flutter analyze` 통과**
- [ ] **Step 6: 커밋** — `feat(guidance): 편집 화면 상단을 제목 + 정리표로`

### Task 3: 첨부 버튼 줄 · 경과 카드 · 펼치는 들은 말·판단·조치

**Files:**
- Modify: `lib/features/guidance/presentation/screens/guidance_edit_screen.dart`
- Modify (기대값): `test/features/guidance/presentation/guidance_edit_attachments_test.dart`, `guidance_edit_screen_test.dart`
- Test: `test/features/guidance/presentation/guidance_edit_layout_test.dart`(Task 2 파일에 추가)

**Interfaces:**
- Consumes: Task 2 화면, 새 문자열.
- Produces: 정리표 아래 순서 = 첨부 버튼 한 줄(`recordKey` 채움 네이비+빨간 점 `recordShort` · `importImageKey` `importImageShort` · `importAudioKey` `importAudioShort`, 세 버튼 같은 폭) → 붙이지 못한 녹음 경고(있을 때) → `AttachmentTile` 목록 → `importHintSchoolPhone` → 경과(카드형 입력, 칸 이름 `labelFacts`, minLines 3~4, `factsKey`) → 들은 말·판단·조치: 비었으면 점선 테두리 버튼 둘 한 줄(`addQuotesKey`/`addActionsKey`, `ButtonSemantics` 또는 `OutlinedButton`) → 누르면 그 자리에 입력칸(`quotesKey`/`actionsKey`, `hintText: quotesHint/actionsHint`) + 포커스. 펼침 상태 `_showQuotes`/`_showActions`는 `_load()` 끝에서 내용 유무로 정하고, 한 번 펼치면 접지 않는다. 첨부 영역 라벨(`labelAttachments`) 줄은 없앤다(구현자 판단으로 남겨도 됨 — 남기면 한 줄).

- [ ] **Step 1: 테스트** — (a) 첨부 버튼 줄 dy < 경과 dy, 정리표 dy < 첨부 버튼 dy. (b) 새 기록: `quotesKey`·`actionsKey` 없음, `addQuotesKey` 누르면 `quotesKey` 나타나고 포커스. (c) 들은 말에 내용 있는 기록을 열면(실제 DB, `runAsync`) `quotesKey` 처음부터 보이고 `addQuotesKey` 없음. (d) 펼친 칸 비워도 접히지 않음. (e) 320pt 넘침 없음. (f) 버튼 글자 `녹음`/`사진`/`녹음 파일`.
- [ ] **Step 2: FAIL 확인**
- [ ] **Step 3: 구현**
- [ ] **Step 4: 기존 테스트 기대값 고치기** — 버튼을 글자로 찾던 곳은 키로, quotesHint/actionsHint는 펼친 뒤 입력칸 안내로, 첨부 흐름 테스트(녹음·가져오기·다시 붙이기·`startRecording`)는 그대로 통과해야 한다. 선언 수 유지.
- [ ] **Step 5: 전체 `flutter test` + `flutter analyze`**
- [ ] **Step 6: CLAUDE.md "지도 기록" 절에 편집 화면 배치 한 단락(B안, ⓘ 둘, 언제 시트, 펼치는 칸) + 테스트 수 갱신(전체 실행 실측값)**
- [ ] **Step 7: 커밋** — `feat(guidance): 첨부 버튼·경과·펼치는 들은 말·판단·조치`

### Task 4: 시뮬레이터 확인 (컨트롤러가 verify 스킬로)

- [ ] `launch.sh --keep-data`, 지도 기록 켬 → 새 기록 화면 캡처(402pt)를 시안 B와 비교 → ⓘ 둘·언제 시트·`+ 들은 말` 펼침 · 저장 → 기록 수정으로 다시 열어 들은 말 펼쳐져 있음 · `녹음으로 새 기록` 흐름 그대로. 증거 `~/.planroutine/verify/<RUN_ID>/guidance-edit-b/`. 끝나면 지도 기록 끔.
