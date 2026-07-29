# 설정 화면 정리 — 도장 시트 + 버스 설정 화면

- 날짜: 2026-07-30
- 상태: 승인됨 (구현 계획 대기)
- 범위: 설정 탭 정보구조. 기능 추가 없음, 배치와 진입 경로만 바꾼다.

## 문제

설정 탭이 섹션 10개, 행 19개다(버스 켜짐 · 캘린더 미연결 기준). 스크롤 세 화면 반.

직접적인 계기는 **도장 모양 줄이 두 줄이 된 것**이다. `화면 테마`는 라벨과 세그먼트가
한 줄인데 `도장 모양`만 칩 4개가 라벨 옆에 못 들어가 아래로 내려갔다. 즉 문제는
"칩이 많다"가 아니라 **한 화면에 행 문법이 두 종류**라는 것이고, 도장은 앞으로 더
늘어나는 축이라(`stamp_settings_tiles.dart`의 주석이 그렇게 적고 있다) 칩을 이 자리에
두는 한 계속 커진다.

두 번째로 무거운 것은 버스다. 켜면 정류장 2 · 카드 모양 · 시간대 2로 여섯 행을 쓴다.

## 검토한 다섯 방향

| | 방향 | 왜 안 골랐나 |
|---|---|---|
| 1 | 목적지 목록 (iOS 설정앱형 전면 drill-down) | 최종형으로는 가장 깔끔하지만, 아홉 섹션 중 무거운 건 셋뿐이라 나머지까지 하위 화면으로 미는 건 탭 한 번을 더 받고 얻는 게 적다 |
| 2 | 제자리 아코디언 | 가장 싸지만 **도장 두 줄 문제를 그대로 남긴다** |
| 3 | 대분류 넷으로 병합 | 세로 회수는 가장 크지만 부제(기능 소개)를 잃는다. 안 5 이후에 얹을 수 있다 |
| 4 | 자주 쓰는 것 / 더 보기 | 접힌 줄이 무엇을 감췄는지 말해주지 않으면 휴지통을 못 찾는다. "자주 쓰는 것" 셋의 근거도 없다 |
| **5** | **깊은 것만 상세로 (채택)** | 회수량이 가장 크면서 손대는 파일이 가장 적다 |

안 1은 폐기가 아니라 **다음 단계**다. 안 5가 만드는 상세 화면 둘이 그 첫 두 칸이다.

## 설계

### 도장 모양 — 한 줄 + 바텀시트

설정 탭의 행은 한 줄로 줄인다.

```
완료 도장
오늘 탭에서 체크할 때 찍히는 도장
   도장 모양                     판다 ›
   이미 찍은 도장 흐리게              ●━
```

`도장 모양`을 누르면 시트가 올라온다 — 2열 그리드, 각 칸에 실제 도장 미리보기.

- **`CompletionSeal`을 그대로 재사용한다.** `animation: AlwaysStoppedAnimation(1)`,
  `dimmed: false`. 미리보기 전용 위젯을 새로 그리면 실제 도장과 반드시 어긋난다.
  `test/tools/seal_preview.dart`가 이미 같은 방식으로 4종을 렌더한다.
- **선택 표시는 색 + 형태 둘 다.** 골드 테두리 + 옅은 배경 + 라벨 옆 체크.
  캘린더 목록에서 ★를 남긴 것과 같은 이유로 비색상 단서가 하나 필요하다.
- **고르면 즉시 저장하고 닫는다.** 확인 버튼을 두지 않는다 — 되돌리기가 시트를 한 번 더
  여는 것뿐이라 저렴하다.
- `useSafeArea: true`. 짧은 시트라 상단까지 뻗지는 않지만, 이 리포에는 그 기본값(false)에
  물려 제목이 다이나믹 아일랜드와 겹쳤던 전례가 있다(`bus_stop_confirm_sheet`). 규칙으로
  지킨다.
- 그리드는 개수가 늘어도 **2열 유지** → 6종이면 3줄, 시트 높이만 자란다. 설정 화면은
  변하지 않는다.

`stamp_settings_tiles.dart`의 파일 주석에 있는 규칙 —
"개수가 고정된 설정은 세그먼트, 늘어나는 설정은 칩" — 을
**"늘어나는 설정은 시트"** 로 갱신한다. 규칙이 바뀐 자리를 남기지 않으면 다음 사람이
칩으로 되돌린다.

### 버스 도착 — 상세 화면

`AppRoutes.busSettings = '/bus/settings'`를 ShellRoute 안에 `NoTransitionPage`로
등록한다(`/trash`·`/import`와 같은 자리 → 탭바 유지).

**시트가 아니라 화면인 이유**: 이 설정 안에서 정류장 검색(`/bus/stops`, 풀스크린)과
`showTimePicker`를 다시 띄워야 한다. 시트 위에서 풀스크린을 push하면 시트가 가려진 채
뒤에 남고 돌아올 때 다시 나타난다. 화면이면 `설정 › 버스 도착 › 정류장 검색`으로
자연스럽게 쌓이고 뒤로가기 한 번씩이 순서대로 맞는다.

**`BusSettingsTiles` 위젯 자체는 손대지 않는다.** 새 화면이 감싸기만 한다 —
`bus_settings_tiles_test.dart`의 9건이 무수정 통과한다.

섹션 부제 `오늘 탭 맨 위에 출퇴근 버스 도착시간을 보여줍니다`는 **화면 상단 설명으로
옮긴다.** 처음 쓰는 사람에게 이 문장은 기능 소개다 — 안 3에서 걱정한 "부제가 사라져
기능을 못 알아보는" 함정을 여기서 피한다.

설정 탭에는 요약 한 줄만 남는다.

```
버스 도착
   버스 도착                 켜짐 · 2곳 ›
```

### 요약 문구는 순수 함수

`buildBusSettingsSummary(BusSettings) → String`

| 상태 | 문구 |
|---|---|
| `enabled == false` | `꺼짐` |
| 켜짐 · 정류장 0곳 | `켜짐 · 정류장 없음` |
| 켜짐 · 정류장 1곳 | `켜짐 · 1곳` |
| 켜짐 · 정류장 2곳 | `켜짐 · 2곳` |

이 리포는 요약 문구를 순수 함수로 두는 패턴이 이미 있다(`buildFilterSummary`,
`buildBusCardView`, `buildTodayView`). 유닛 테스트로 고정한다.

**정류장 이름을 넣지 않는다**(`우방아파트→중앙공원`). 320pt에서 넘친다. 이름은 화면
안에서 본다.

### AI 자동화 (고급) 제거

`설정 › AI 자동화 (고급)` 섹션과 `AiTaskShareTile`을 설정 화면에서 뺀다.

**`aiTaskShareEnabledProvider`와 `event_edit_dialog.dart:105`의 분기는 남긴다.**
provider까지 지우면 되살릴 때 다시 만들어야 하고, 저장값도 버려진다.

⚠️ **선행 조건**: 이 토글이 켜져 있으면 섹션 제거 후 `AI로 보내기`를 끌 방법이
없어진다(다이얼로그가 provider를 계속 watch한다). 기본값이 `false`라 안 켰으면 무해하다.
**구현 전에 실기기에서 토글이 꺼져 있는지 확인하고, 켜져 있으면 끄고 시작한다.**

## 손대는 파일

### 신규

| 파일 | 역할 |
|---|---|
| `lib/features/settings/presentation/widgets/stamp_style_sheet.dart` | 2열 그리드 바텀시트 + `show()` |
| `lib/features/settings/presentation/widgets/bus_summary_list_tile.dart` | 설정 탭의 버스 요약 한 줄 |
| `lib/features/bus/presentation/screens/bus_settings_screen.dart` | `BusSettingsTiles`를 감싸는 화면 |
| `lib/features/bus/domain/bus_settings_summary.dart` | `buildBusSettingsSummary` 순수 함수 |

### 수정

| 파일 | 변경 |
|---|---|
| `lib/features/settings/presentation/widgets/stamp_settings_tiles.dart` | `_StyleRow`(라벨 줄 + 칩 Wrap) → 한 줄 `ListTile`. 파일 주석 규칙 갱신 |
| `lib/features/settings/presentation/screens/settings_screen.dart` | 버스 섹션 → `BusSummaryListTile`. AI 자동화 섹션 제거 |
| `lib/core/router/app_router.dart` | `AppRoutes.busSettings` + ShellRoute 등록 |
| `lib/core/constants/strings/settings_strings.dart` | `aiShare*` 제거, 도장 시트 제목 추가 |
| `lib/core/constants/strings/bus_strings.dart` | 화면 제목 · 요약 문구 |

### 남기는 것

`ai_task_share_provider.dart`, `ai_task_share_tile.dart`, `event_edit_dialog.dart`의 분기.
설정 화면에서 참조만 끊는다.

## 테스트

### 신규

- `test/features/settings/stamp_style_sheet_test.dart`
  - **`SealStyle.values` 전부가 렌더되는지** — 새 모양을 추가하고 시트에 빠뜨리는 것을
    막는 가드. 이 리포의 습관(빠뜨려도 컴파일이 통과하는 자리에 가드를 둔다)을 따른다.
  - 고르면 `stampSettingsProvider`에 저장되고 시트가 닫힌다.
  - 선택된 칸에 체크가 있다(색 말고 형태 단서).
- `test/features/bus/bus_settings_summary_test.dart` — 순수 함수 네 분기.
- `test/features/bus/bus_settings_screen_test.dart` — 화면이 `BusSettingsTiles`를 담고,
  상단 설명이 보인다.
- `test/features/settings/bus_summary_list_tile_test.dart` — 요약 줄이 문구를 보여주고,
  누르면 `/bus/settings`로 push한다.

### 갱신 (삭제 아님)

- `test/features/settings/stamp_settings_tiles_test.dart`
  - 칩을 찾던 3건(`세 가지 도장 모양이 모두 선택지로 보인다`, `결재를 고르면…`,
    `좋아요를 고르면…`)은 **모양 선택 검증을 시트 테스트로 이관**하고, 이 파일에는
    `현재 도장 이름이 한 줄에 보인다` / `누르면 시트가 열린다`를 남긴다.
  - `기본값은 완료 도장 + 흐리게 켜짐`, `흐리게 스위치를 끄면…`은 그대로.

### 무수정

- `test/features/bus/bus_settings_tiles_test.dart` 9건 — 위젯을 옮기지 않으므로 그대로.

### 검증

`flutter analyze` + `flutter test` 통과 후 **iOS 시뮬레이터로 직접 확인**한다. 특히
시트가 열리고 도장 네 종이 실제 그림으로 보이는지 — 에셋 마크(도마뱀)는 위젯 존재
검증만으로는 못 지킨다(`rootBundle` 로드까지 봐야 한다).

## 회수량

버스 켜짐 · 캘린더 미연결 기준.

| | 전 | 후 | 출처 |
|---|---|---|---|
| 설정 탭 행 | 19 | 12 | 버스 −5 · 도장 −1 · AI −1 |
| 도장 모양 줄 | 2줄 | 1줄 | |
| 섹션 | 10 | 9 | AI 자동화 제거 |

## 다음 단계 (이번 범위 아님)

- 섹션 헤더 9개와 부제는 그대로 남는다. 지면 소음이 더 거슬리면 **안 3**(대분류 넷으로
  병합)을 얹는다. 세로 회수의 출처가 달라 이번 작업과 겹치지 않는다.
- 설정이 더 늘면 **안 1**(전면 drill-down)로 간다. 이번에 만드는 상세 화면 둘이 그
  첫 두 칸이다.
