# 설정 화면 정리 (도장 시트 + 버스 화면) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 설정 탭에서 도장 모양을 한 줄 + 바텀시트로, 버스 설정 여섯 행을 한 줄 + 상세 화면으로 빼고 AI 자동화 섹션을 제거한다.

**Architecture:** 기능 추가는 없다. `StampSettingsTiles`의 칩 `Wrap`을 한 줄 `ListTile`로 바꾸고 선택지는 새 바텀시트(`StampStyleSheet`)로 옮긴다. `BusSettingsTiles` 위젯은 그대로 두고 새 화면(`BusSettingsScreen`)이 감싸며, 설정 탭에는 순수 함수가 만든 요약 한 줄만 남는다.

**Tech Stack:** Flutter 3.x / Riverpod / GoRouter(ShellRoute) / shared_preferences / flutter_test

## Global Constraints

- 한글 UI, 한글 주석. 문자열 하드코딩 금지 — 공통은 `AppStrings`, 도메인은 `*Strings` 클래스.
- 색상은 `AppColors`, 크기는 `AppSizes`. 리터럴 금지.
- 상태관리는 Riverpod만. 다른 라이브러리 금지.
- **기존 테스트 삭제 절대 금지.** 이동·갱신만 한다.
- 파일명 snake_case / 클래스명 PascalCase.
- `!` 강제 언래핑 금지.
- 설정 섹션은 `SettingsSection` wrapper + `widgets/{name}_list_tile.dart` 패턴을 따른다.
- 각 Task 끝에서 `flutter analyze`가 깨끗해야 커밋한다.

## 스펙에서 바뀐 것 (근거 있는 이탈)

스펙은 `BusSettingsScreen`을 `lib/features/bus/presentation/screens/`에 두라고 했다.
**`lib/features/settings/presentation/screens/`로 옮긴다.**

- `BusSettingsTiles`가 이미 `features/settings/presentation/widgets/`에 산다. 화면을 bus에
  두면 **bus → settings 역방향 import**가 생긴다(지금은 settings → bus 한 방향뿐).
- 그 위젯을 bus로 옮기면 `bus_settings_tiles_test.dart`의 import가 바뀐다. "테스트 9건
  무수정"이라는 스펙의 약속이 깨진다.
- `buildBusSettingsSummary`는 스펙대로 `features/bus/domain/`에 둔다 — settings가 bus
  domain을 참조하는 것은 기존 방향이다.

## File Structure

### 신규

| 파일 | 책임 |
|---|---|
| `lib/features/bus/domain/bus_settings_summary.dart` | `buildBusSettingsSummary` 순수 함수 하나 |
| `lib/features/settings/presentation/screens/bus_settings_screen.dart` | AppBar + 설명문 + `BusSettingsTiles` |
| `lib/features/settings/presentation/widgets/bus_summary_list_tile.dart` | 설정 탭의 요약 한 줄 → `/bus/settings` push |
| `lib/features/settings/presentation/widgets/stamp_style_sheet.dart` | 2열 그리드 바텀시트 + `show()` |
| `test/features/bus/bus_settings_summary_test.dart` | 순수 함수 네 분기 |
| `test/features/settings/bus_settings_screen_test.dart` | 화면이 설명문 + 타일을 담는다 |
| `test/features/settings/bus_summary_list_tile_test.dart` | 요약 문구 + 탭 |
| `test/features/settings/stamp_style_sheet_test.dart` | 전 모양 렌더 가드 + 선택 저장 |

### 수정

| 파일 | 변경 |
|---|---|
| `lib/core/constants/strings/bus_strings.dart` | 요약 문구 3개 추가 |
| `lib/core/constants/strings/settings_strings.dart` | `stampStyleSheetTitle` 추가, `aiShare*` 5개 제거 |
| `lib/core/constants/strings/today_strings.dart` | 변경 없음 (라벨 재사용) |
| `lib/core/router/app_router.dart` | `AppRoutes.busSettings` + ShellRoute 등록 |
| `lib/features/settings/presentation/widgets/stamp_settings_tiles.dart` | `_StyleRow` → 한 줄 `ListTile`, 주석 규칙 갱신 |
| `lib/features/settings/presentation/screens/settings_screen.dart` | 버스 섹션 child 교체, AI 섹션 제거 |
| `test/features/settings/stamp_settings_tiles_test.dart` | 칩 검증 3건 → 한 줄/시트 열림 검증 |
| `test/tools/visual_check.dart` | `AiTaskShareTile` 참조 제거 |

### 삭제

| 파일 | 이유 |
|---|---|
| `lib/features/settings/presentation/widgets/ai_task_share_tile.dart` | 설정 화면에서 유일한 사용처가 사라진다 |

**남긴다:** `ai_task_share_provider.dart`, `event_edit_dialog.dart:105`의 분기.
provider까지 지우면 되살릴 때 저장값을 버린다.

---

### Task 1: 버스 요약 순수 함수

**Files:**
- Create: `lib/features/bus/domain/bus_settings_summary.dart`
- Modify: `lib/core/constants/strings/bus_strings.dart`
- Test: `test/features/bus/bus_settings_summary_test.dart`

**Interfaces:**
- Consumes: `BusSettings`(`lib/features/bus/domain/bus_settings.dart`) — `enabled`, `departure`, `arrival`
- Produces: `String buildBusSettingsSummary(BusSettings settings)`
- Produces: `BusStrings.summaryOff`, `BusStrings.summaryNoStop`, `BusStrings.summaryStops(int)`

- [ ] **Step 1: 문자열 3개를 추가한다**

`lib/core/constants/strings/bus_strings.dart`의 `static const rangeInverted = '시작이 종료보다 빠르게 두세요';` 바로 아래에 넣는다:

```dart
  // ── 설정 탭 요약 한 줄 ─────────────────────────────────────
  /// 설정 탭에서 버스 섹션이 차지하던 여섯 줄을 대신하는 한 줄.
  ///
  /// **정류장 이름을 넣지 않는다.** `우방아파트→중앙공원`은 320pt에서 넘친다.
  /// 이름은 상세 화면 안에서 본다.
  static const summaryOff = '꺼짐';
  static const summaryNoStop = '켜짐 · 정류장 없음';
  static String summaryStops(int n) => '켜짐 · $n곳';
```

- [ ] **Step 2: 실패하는 테스트를 쓴다**

Create `test/features/bus/bus_settings_summary_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/bus/domain/bus_settings.dart';
import 'package:planroutine/features/bus/domain/bus_settings_summary.dart';
import 'package:planroutine/features/bus/domain/bus_stop.dart';

BusStop _stop(String name) => BusStop(
      nodeId: 'GGB$name',
      nodeNm: name,
      nodeNo: 26044,
      regionName: '군포',
    );

void main() {
  group('buildBusSettingsSummary', () {
    test('꺼져 있으면 꺼짐', () {
      expect(
        buildBusSettingsSummary(BusSettings.defaults),
        BusStrings.summaryOff,
      );
    });

    test('켜져 있고 정류장이 없으면 그 사실을 말한다', () {
      expect(
        buildBusSettingsSummary(BusSettings.defaults.copyWith(enabled: true)),
        BusStrings.summaryNoStop,
      );
    });

    test('한 곳만 등록하면 1곳', () {
      final settings = BusSettings.defaults
          .copyWith(enabled: true, departure: _stop('우방아파트'));
      expect(buildBusSettingsSummary(settings), BusStrings.summaryStops(1));
    });

    test('두 곳을 등록하면 2곳', () {
      final settings = BusSettings.defaults.copyWith(
        enabled: true,
        departure: _stop('우방아파트'),
        arrival: _stop('중앙공원'),
      );
      expect(buildBusSettingsSummary(settings), BusStrings.summaryStops(2));
    });

    test('꺼져 있으면 정류장이 있어도 꺼짐이다', () {
      // 켜짐 여부가 먼저다 — 정류장이 남아 있다고 켜진 것처럼 보이면 안 된다.
      final settings = BusSettings.defaults.copyWith(
        departure: _stop('우방아파트'),
        arrival: _stop('중앙공원'),
      );
      expect(buildBusSettingsSummary(settings), BusStrings.summaryOff);
    });
  });
}
```

- [ ] **Step 3: 실패를 확인한다**

Run: `flutter test test/features/bus/bus_settings_summary_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../bus_settings_summary.dart'`

`BusStop`의 생성자 인자 이름이 위 헬퍼와 다르면 `lib/features/bus/domain/bus_stop.dart`를 열어 실제 필드에 맞춘다. **테스트 헬퍼만 고치고 프로덕션 코드를 헬퍼에 맞추지 않는다.**

- [ ] **Step 4: 순수 함수를 만든다**

Create `lib/features/bus/domain/bus_settings_summary.dart`:

```dart
import '../../../core/constants/app_strings.dart';
import 'bus_settings.dart';

/// 설정 탭에 남는 버스 요약 한 줄.
///
/// 순수 함수로 둔다 — 이 리포가 요약 문구를 다루는 방식이다
/// (`buildFilterSummary`·`buildBusCardView`·`buildTodayView`). 위젯 안에서
/// 조립하면 분기를 유닛 테스트로 고정할 수 없다.
///
/// **켜짐 여부를 먼저 본다.** 꺼 둔 사용자의 설정에도 정류장은 남아 있으므로,
/// 정류장 수를 먼저 보면 꺼진 기능이 켜진 것처럼 읽힌다.
String buildBusSettingsSummary(BusSettings settings) {
  if (!settings.enabled) return BusStrings.summaryOff;

  var count = 0;
  if (settings.departure != null) count++;
  if (settings.arrival != null) count++;

  if (count == 0) return BusStrings.summaryNoStop;
  return BusStrings.summaryStops(count);
}
```

- [ ] **Step 5: 통과를 확인한다**

Run: `flutter test test/features/bus/bus_settings_summary_test.dart`
Expected: PASS (5건)

- [ ] **Step 6: analyze + 커밋**

```bash
flutter analyze lib/features/bus/domain/bus_settings_summary.dart lib/core/constants/strings/bus_strings.dart
git add lib/features/bus/domain/bus_settings_summary.dart lib/core/constants/strings/bus_strings.dart test/features/bus/bus_settings_summary_test.dart
git commit -m "feat(bus): 설정 탭에 남길 요약 한 줄을 순수 함수로 만든다"
```

---

### Task 2: 버스 설정 화면 + 라우트

**Files:**
- Create: `lib/features/settings/presentation/screens/bus_settings_screen.dart`
- Modify: `lib/core/router/app_router.dart`
- Test: `test/features/settings/bus_settings_screen_test.dart`

**Interfaces:**
- Consumes: `BusSettingsTiles`(`lib/features/settings/presentation/widgets/bus_settings_tiles.dart`), `BusStrings.section`, `BusStrings.sectionDescription`
- Produces: `class BusSettingsScreen extends StatelessWidget`
- Produces: `AppRoutes.busSettings == '/bus/settings'`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

Create `test/features/settings/bus_settings_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/settings/presentation/screens/bus_settings_screen.dart';
import 'package:planroutine/features/settings/presentation/widgets/bus_settings_tiles.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: BusSettingsScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('화면이 설정 타일을 담는다', (tester) async {
    await pump(tester);

    expect(find.byType(BusSettingsTiles), findsOneWidget);
    expect(find.byKey(BusSettingsTiles.switchKey), findsOneWidget);
  });

  testWidgets('섹션 부제였던 기능 설명이 화면 안에 남아 있다', (tester) async {
    // 설정 탭에서 섹션 헤더를 걷어내면서 잃을 뻔한 문장이다 —
    // 처음 쓰는 사람에게 이 한 줄이 기능 소개다.
    await pump(tester);

    expect(find.text(BusStrings.sectionDescription), findsOneWidget);
  });

  testWidgets('제목이 버스 도착이다', (tester) async {
    await pump(tester);

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text(BusStrings.section)),
      findsOneWidget,
    );
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `flutter test test/features/settings/bus_settings_screen_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../bus_settings_screen.dart'`

- [ ] **Step 3: 화면을 만든다**

Create `lib/features/settings/presentation/screens/bus_settings_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../widgets/bus_settings_tiles.dart';

/// `설정 › 버스 도착` 상세 화면.
///
/// **시트가 아니라 화면인 이유**: 이 안에서 정류장 검색(`/bus/stops`, 풀스크린)과
/// `showTimePicker`를 다시 띄운다. 시트 위에 풀스크린을 push하면 시트가 가려진 채
/// 뒤에 남고 돌아올 때 다시 나타난다. 화면이면 `설정 › 버스 도착 › 정류장 검색`으로
/// 쌓이고 뒤로가기 한 번씩이 순서대로 맞는다.
///
/// **[BusSettingsTiles]를 옮기지 않고 감싸기만 한다** — 그 위젯의 테스트 9건이
/// 그대로 남는다.
///
/// 이 화면은 `features/bus/`가 아니라 여기 산다. 위젯이 이미 settings 아래 있어
/// bus에 두면 bus → settings 역방향 import가 생긴다(지금은 settings → bus 한 방향).
class BusSettingsScreen extends StatelessWidget {
  const BusSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(BusStrings.section, style: AppTextStyles.heading),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSizes.spacing24),
        children: [
          // 설정 탭 섹션 부제가 여기로 옮겨 왔다. 걷어내면 기능 소개가 사라진다.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.pagePadding,
              AppSizes.spacing12,
              AppSizes.pagePadding,
              AppSizes.spacing8,
            ),
            child: Text(
              BusStrings.sectionDescription,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                height: 1.4,
                color: AppColors.sub,
              ),
            ),
          ),
          const BusSettingsTiles(),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 통과를 확인한다**

Run: `flutter test test/features/settings/bus_settings_screen_test.dart`
Expected: PASS (3건)

- [ ] **Step 5: 라우트를 등록한다**

`lib/core/router/app_router.dart` — `AppRoutes`에 한 줄 추가:

```dart
  static const busStops = '/bus/stops';
  static const busSettings = '/bus/settings';
```

import 추가:

```dart
import '../../features/settings/presentation/screens/bus_settings_screen.dart';
```

ShellRoute의 `routes:` 배열에서 `AppRoutes.busStops` GoRoute **앞에** 넣는다:

```dart
            GoRoute(
              path: AppRoutes.busSettings,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: BusSettingsScreen(),
              ),
            ),
```

ShellRoute 안에 두는 이유는 `/trash`·`/import`와 같다 — 탭바가 유지되고,
`/bus/stops`가 같은 Shell에 있어 `설정 › 버스 도착 › 정류장 검색`이 자연스럽게 쌓인다.

- [ ] **Step 6: analyze + 커밋**

```bash
flutter analyze lib/core/router/app_router.dart lib/features/settings/presentation/screens/bus_settings_screen.dart
flutter test test/features/settings/bus_settings_screen_test.dart
git add lib/core/router/app_router.dart lib/features/settings/presentation/screens/bus_settings_screen.dart test/features/settings/bus_settings_screen_test.dart
git commit -m "feat(bus): 버스 설정을 상세 화면으로 뺀다"
```

---

### Task 3: 설정 탭의 버스 요약 한 줄

**Files:**
- Create: `lib/features/settings/presentation/widgets/bus_summary_list_tile.dart`
- Modify: `lib/features/settings/presentation/screens/settings_screen.dart`
- Test: `test/features/settings/bus_summary_list_tile_test.dart`

**Interfaces:**
- Consumes: `buildBusSettingsSummary`(Task 1), `AppRoutes.busSettings`(Task 2), `busSettingsProvider`(`lib/features/bus/presentation/providers/bus_providers.dart`)
- Produces: `class BusSummaryListTile extends ConsumerWidget`, `BusSummaryListTile.tileKey`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

Create `test/features/settings/bus_summary_list_tile_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/router/app_router.dart';
import 'package:planroutine/features/settings/presentation/widgets/bus_summary_list_tile.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// 요약 타일만 띄우고, push 대상 라우트에는 표식 위젯을 둔다.
  Future<void> pump(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: BusSummaryListTile()),
        ),
        GoRoute(
          path: AppRoutes.busSettings,
          builder: (_, _) => const Scaffold(body: Text('버스설정화면')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('기본은 꺼짐으로 보인다', (tester) async {
    await pump(tester);

    expect(find.text(BusStrings.section), findsOneWidget);
    expect(find.text(BusStrings.summaryOff), findsOneWidget);
  });

  testWidgets('누르면 버스 설정 화면으로 간다', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(BusSummaryListTile.tileKey));
    await tester.pumpAndSettle();

    expect(find.text('버스설정화면'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `flutter test test/features/settings/bus_summary_list_tile_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../bus_summary_list_tile.dart'`

- [ ] **Step 3: 타일을 만든다**

Create `lib/features/settings/presentation/widgets/bus_summary_list_tile.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/router/app_router.dart';
import '../../../bus/domain/bus_settings.dart';
import '../../../bus/domain/bus_settings_summary.dart';
import '../../../bus/presentation/providers/bus_providers.dart';

/// 설정 탭의 버스 요약 한 줄 — 상세 화면으로 보낸다.
///
/// 모양은 [TrashListTile]과 같다(아이콘 + 제목 + 현재 상태 + chevron). 설정 탭에서
/// 화면으로 나가는 줄은 전부 이 형태여야 눌러야 하는 줄인지 한눈에 보인다.
///
/// **로딩 중에도 기본값으로 그린다** — `BusSettingsTiles`와 같은 이유다. null에
/// `SizedBox.shrink()`를 돌려주면 `SharedPreferences.getInstance()`를 기다리는 한
/// 프레임 동안 이 섹션만 헤더와 Divider 사이가 비어 깜빡인다.
class BusSummaryListTile extends ConsumerWidget {
  const BusSummaryListTile({super.key});

  static const tileKey = Key('bus_summary_tile');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(busSettingsProvider).valueOrNull ?? BusSettings.defaults;

    return ListTile(
      key: tileKey,
      leading: Icon(Icons.directions_bus_outlined, color: AppColors.primary),
      title: const Text(BusStrings.section),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            buildBusSettingsSummary(settings),
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              color: AppColors.sub,
            ),
          ),
          const SizedBox(width: AppSizes.spacing4),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => context.push(AppRoutes.busSettings),
    );
  }
}
```

- [ ] **Step 4: 통과를 확인한다**

Run: `flutter test test/features/settings/bus_summary_list_tile_test.dart`
Expected: PASS (2건)

- [ ] **Step 5: 설정 화면에서 갈아 끼운다**

`lib/features/settings/presentation/screens/settings_screen.dart`:

import 교체 — `import '../widgets/bus_settings_tiles.dart';` 를 지우고
`import '../widgets/bus_summary_list_tile.dart';` 를 넣는다(알파벳 순서 유지).

본문에서:

```dart
          const SettingsSection(
            title: BusStrings.section,
            subtitle: BusStrings.sectionDescription,
            child: BusSettingsTiles(),
          ),
```

를 다음으로 바꾼다:

```dart
          const SettingsSection(
            title: BusStrings.section,
            subtitle: BusStrings.sectionDescription,
            child: BusSummaryListTile(),
          ),
```

- [ ] **Step 6: 전체 테스트 + analyze + 커밋**

```bash
flutter analyze
flutter test
git add -A
git commit -m "feat(settings): 버스 섹션을 요약 한 줄로 줄인다"
```

기대: 기존 `bus_settings_tiles_test.dart` 9건은 위젯을 직접 pump하므로 그대로 통과한다.
실패하면 그 위젯을 건드린 것이므로 되돌린다.

---

### Task 4: 도장 모양 바텀시트

**Files:**
- Create: `lib/features/settings/presentation/widgets/stamp_style_sheet.dart`
- Modify: `lib/core/constants/strings/settings_strings.dart`
- Test: `test/features/settings/stamp_style_sheet_test.dart`

**Interfaces:**
- Consumes: `SealStyle`·`StampSettings`(`lib/features/today/domain/stamp_settings.dart`), `CompletionSeal`(`lib/features/today/presentation/widgets/completion_seal.dart`), `stampSettingsProvider`
- Produces: `class StampStyleSheet extends ConsumerWidget`, `static Future<void> StampStyleSheet.show(BuildContext)`, `static Key StampStyleSheet.optionKey(SealStyle)`
- Produces: `SettingsStrings.stampStyleSheetTitle`

- [ ] **Step 1: 문자열을 추가한다**

`lib/core/constants/strings/settings_strings.dart`의 `stampDimDescription` 아래:

```dart
  /// 도장 모양 시트 제목. 설정 탭의 행 라벨과 같은 말이어야 시트가 그 행의
  /// 연장으로 읽힌다 — 다른 말을 쓰면 다른 설정을 연 것처럼 보인다.
  static const stampStyleSheetTitle = stampStyleLabel;
```

- [ ] **Step 2: 실패하는 테스트를 쓴다**

Create `test/features/settings/stamp_style_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/settings/presentation/providers/stamp_settings_provider.dart';
import 'package:planroutine/features/settings/presentation/widgets/stamp_style_sheet.dart';
import 'package:planroutine/features/today/domain/stamp_settings.dart';
import 'package:planroutine/features/today/presentation/widgets/completion_seal.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// 시트를 연 상태로 만든다. 여는 버튼을 하나 두고 눌러 실제 경로를 탄다 —
  /// 시트 본문만 pump하면 `show()`의 `useSafeArea` 같은 설정이 검증에서 빠진다.
  Future<ProviderContainer> openSheet(WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => StampStyleSheet.show(context),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    return container;
  }

  StampSettings current(ProviderContainer container) =>
      container.read(stampSettingsProvider).requireValue;

  group('도장 모양 시트', () {
    testWidgets('모든 도장 모양이 선택지로 있다', (tester) async {
      // 가드 — 새 모양을 SealStyle에 추가하고 시트에 빠뜨리는 것을 막는다.
      // 개수를 숫자로 박지 않는다(박으면 추가할 때마다 테스트만 고치고 넘어간다).
      await openSheet(tester);

      for (final style in SealStyle.values) {
        expect(
          find.byKey(StampStyleSheet.optionKey(style)),
          findsOneWidget,
          reason: '${style.name} 선택지가 시트에 없다',
        );
      }
    });

    testWidgets('선택지마다 실제 도장이 미리보기로 그려진다', (tester) async {
      // 라벨만으로는 모양을 알 수 없다 — 시트의 존재 이유가 이 미리보기다.
      await openSheet(tester);

      expect(
        find.byType(CompletionSeal),
        findsNWidgets(SealStyle.values.length),
      );
    });

    testWidgets('제목이 보인다', (tester) async {
      await openSheet(tester);

      expect(find.text(SettingsStrings.stampStyleSheetTitle), findsOneWidget);
    });

    testWidgets('고르면 저장되고 시트가 닫힌다', (tester) async {
      final container = await openSheet(tester);

      await tester.tap(find.byKey(StampStyleSheet.optionKey(SealStyle.gecko)));
      await tester.pumpAndSettle();

      expect(current(container).style, SealStyle.gecko);
      expect(find.byType(StampStyleSheet), findsNothing);
    });

    testWidgets('선택된 칸에는 체크가 있다', (tester) async {
      // 색만으로 표시하지 않는다 — 비색상 단서가 하나 있어야 한다.
      await openSheet(tester);

      final checks = find.descendant(
        of: find.byKey(StampStyleSheet.optionKey(SealStyle.complete)),
        matching: find.byIcon(Icons.check),
      );
      expect(checks, findsOneWidget);

      final unchecked = find.descendant(
        of: find.byKey(StampStyleSheet.optionKey(SealStyle.gecko)),
        matching: find.byIcon(Icons.check),
      );
      expect(unchecked, findsNothing);
    });
  });
}
```

- [ ] **Step 3: 실패를 확인한다**

Run: `flutter test test/features/settings/stamp_style_sheet_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../stamp_style_sheet.dart'`

- [ ] **Step 4: 시트를 만든다**

Create `lib/features/settings/presentation/widgets/stamp_style_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../today/domain/stamp_settings.dart';
import '../../../today/presentation/widgets/completion_seal.dart';
import '../providers/stamp_settings_provider.dart';

/// 도장 모양 고르기 — 2열 그리드 바텀시트.
///
/// **설정 탭에 칩 `Wrap`으로 두지 않는다.** 도장이 4종이 되자 라벨 옆에 못 들어가
/// 줄이 둘로 갈라졌고(`화면 테마`는 한 줄인데 이 줄만 두 줄), 도장은 앞으로 더
/// 늘어나는 축이다. 규칙은 이렇게 바뀌었다 —
/// **개수가 고정된 설정은 세그먼트, 늘어나는 설정은 시트.**
/// 시트는 개수가 늘어도 자기 높이만 자라고 설정 화면은 변하지 않는다.
///
/// 미리보기는 [CompletionSeal]을 **그대로** 쓴다. 전용 위젯을 새로 그리면 실제
/// 찍히는 도장과 반드시 어긋난다.
class StampStyleSheet extends ConsumerWidget {
  const StampStyleSheet({super.key});

  /// 선택지 하나를 찾는 키. 라벨 문자열로 찾으면 `완료`가 도장 안 글자와 겹친다.
  static Key optionKey(SealStyle style) => Key('stamp_option_${style.name}');

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      // 기본값(false)은 시트를 화면 top까지 뻗게 하고 그 모드에서는 MediaQuery의
      // top padding이 제거돼 안쪽 SafeArea가 무력해진다 — 이 리포에는 그 함정에
      // 물려 제목이 다이나믹 아일랜드와 겹쳤던 전례가 있다(버스 확인 시트).
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radius18),
        ),
      ),
      builder: (_) => const StampStyleSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected =
        (ref.watch(stampSettingsProvider).valueOrNull ?? StampSettings.defaults)
            .style;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.pagePadding,
          AppSizes.spacing12,
          AppSizes.pagePadding,
          AppSizes.spacing24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.faint,
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.spacing16),
            Text(
              SettingsStrings.stampStyleSheetTitle,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: AppSizes.spacing12),
            // 2열 고정 — 모양이 늘어도 열은 그대로고 줄만 늘어난다.
            // GridView 대신 Wrap을 쓰면 칸 폭이 내용에 따라 들쭉날쭉해진다.
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = AppSizes.spacing8;
                final cellWidth = (constraints.maxWidth - gap) / 2;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final style in SealStyle.values)
                      SizedBox(
                        width: cellWidth,
                        child: _Option(
                          style: style,
                          selected: style == selected,
                          onTap: () async {
                            await ref
                                .read(stampSettingsProvider.notifier)
                                .setStyle(style);
                            if (context.mounted) Navigator.of(context).pop();
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 선택지 한 칸 — 미리보기 도장 + 이름 (+ 골랐으면 체크).
class _Option extends StatelessWidget {
  const _Option({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final SealStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: StampStyleSheet.optionKey(style),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radius12),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spacing12,
          vertical: AppSizes.spacing12,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.radius12),
          // 선택 표시는 색 + 형태 둘 다다. 체크(아래)가 비색상 단서.
          color: selected
              ? AppColors.goldFill.withValues(alpha: 0.10)
              : Colors.transparent,
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // 실제 오늘 탭에 찍히는 위젯 그대로. 안착 상태로 고정해 그린다.
            const SizedBox.shrink(),
            CompletionSeal(
              animation: const AlwaysStoppedAnimation(1),
              style: style,
            ),
            const SizedBox(width: AppSizes.spacing12),
            Expanded(
              child: Text(
                style.label,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.gold : AppColors.ink,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check, size: 18, color: AppColors.gold),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: 통과를 확인한다**

Run: `flutter test test/features/settings/stamp_style_sheet_test.dart`
Expected: PASS (5건)

`AppColors.surface`·`AppColors.line`·`AppColors.ink`·`AppColors.faint`가 실제로
있는지 `lib/core/constants/app_colors.dart`에서 확인한다. 없으면 있는 토큰으로
바꾼다 — **새 토큰을 만들지 않는다**(전역 영향이라 사전 확인 대상).

- [ ] **Step 6: analyze + 커밋**

```bash
flutter analyze lib/features/settings/presentation/widgets/stamp_style_sheet.dart
git add lib/features/settings/presentation/widgets/stamp_style_sheet.dart lib/core/constants/strings/settings_strings.dart test/features/settings/stamp_style_sheet_test.dart
git commit -m "feat(settings): 도장 모양을 미리보기 시트에서 고른다"
```

---

### Task 5: 도장 모양 행을 한 줄로

**Files:**
- Modify: `lib/features/settings/presentation/widgets/stamp_settings_tiles.dart`
- Modify: `test/features/settings/stamp_settings_tiles_test.dart`

**Interfaces:**
- Consumes: `StampStyleSheet.show`(Task 4)
- Produces: `StampSettingsTiles.styleTileKey`

- [ ] **Step 1: 테스트를 갱신한다 (삭제 아님)**

`test/features/settings/stamp_settings_tiles_test.dart`에서 칩을 찾던 세 건
(`세 가지 도장 모양이 모두 선택지로 보인다`, `결재를 고르면 설정에 저장된다`,
`좋아요를 고르면 설정에 저장된다`)을 아래 두 건으로 **대체**한다. 모양 선택 검증은
Task 4의 시트 테스트가 이미 하고 있다(이관).

`기본값은 완료 도장 + 흐리게 켜짐`과 `흐리게 스위치를 끄면 설정에 반영된다`는
손대지 않는다.

`pumpTiles`의 `MaterialApp(home: Scaffold(body: StampSettingsTiles()))`는 그대로 쓴다
(시트는 `showModalBottomSheet`이라 라우터가 필요 없다).

```dart
    testWidgets('현재 도장 이름이 한 줄에 보인다', (tester) async {
      await pumpTiles(tester);

      expect(find.byKey(StampSettingsTiles.styleTileKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(StampSettingsTiles.styleTileKey),
          matching: find.text(TodayStrings.sealComplete),
        ),
        findsOneWidget,
      );
    });

    testWidgets('누르면 도장 모양 시트가 열린다', (tester) async {
      await pumpTiles(tester);

      await tester.tap(find.byKey(StampSettingsTiles.styleTileKey));
      await tester.pumpAndSettle();

      expect(find.byType(StampStyleSheet), findsOneWidget);
    });
```

import 두 줄을 파일 상단에 추가한다:

```dart
import 'package:planroutine/features/settings/presentation/widgets/stamp_style_sheet.dart';
```

(`TodayStrings`는 `app_strings.dart`가 이미 barrel export하므로 기존 import로 족하다.)

- [ ] **Step 2: 실패를 확인한다**

Run: `flutter test test/features/settings/stamp_settings_tiles_test.dart`
Expected: FAIL — `StampSettingsTiles.styleTileKey` 없음 (컴파일 에러)

- [ ] **Step 3: 위젯을 한 줄로 바꾼다**

`lib/features/settings/presentation/widgets/stamp_settings_tiles.dart` 전체를 아래로 교체한다.
`_StyleRow`와 `PillChip` import가 함께 사라진다.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../today/domain/stamp_settings.dart';
import '../providers/stamp_settings_provider.dart';
import 'stamp_style_sheet.dart';

/// 완료 도장 설정 — 도장 모양 한 줄 + "이미 찍은 도장 흐리게" 스위치.
///
/// **모양 선택지는 이 화면에 두지 않는다.** 칩 `Wrap`으로 두던 시절 도장이 4종이
/// 되자 라벨 옆에 못 들어가 줄이 둘로 갈라졌다 — 같은 화면의 `화면 테마`는 라벨과
/// 세그먼트가 한 줄이라, 한 화면에 행 문법이 두 종류가 됐다.
///
/// 규칙: **개수가 고정된 설정은 세그먼트**(화면 테마 3종),
/// **늘어나는 설정은 시트**([StampStyleSheet]). 도장은 늘어나는 축이라
/// 5번째가 들어와도 이 화면은 변하지 않는다.
class StampSettingsTiles extends ConsumerWidget {
  const StampSettingsTiles({super.key});

  static const styleTileKey = Key('stamp_style_tile');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(stampSettingsProvider).valueOrNull ?? StampSettings.defaults;
    final notifier = ref.read(stampSettingsProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          key: styleTileKey,
          leading: Icon(Icons.approval_outlined, color: AppColors.primary),
          title: Text(
            SettingsStrings.stampStyleLabel,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                settings.style.label,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSizes.spacing4),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () => StampStyleSheet.show(context),
        ),
        SwitchListTile(
          key: const Key('stamp_dim_switch'),
          value: settings.dimPreviousStamps,
          onChanged: notifier.setDimPreviousStamps,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSizes.spacing16,
          ),
          title: Text(
            SettingsStrings.stampDimLabel,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            SettingsStrings.stampDimDescription,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: 통과를 확인한다**

Run: `flutter test test/features/settings/stamp_settings_tiles_test.dart`
Expected: PASS (4건 — 기본값 / 한 줄 표시 / 시트 열림 / 흐리게)

- [ ] **Step 5: `PillChip`이 고아가 됐는지 본다**

Run: `grep -rn "PillChip" lib/`
`lib/shared/widgets/pill_chip.dart` 외에 사용처가 남아 있으면 **그대로 둔다**
(입력 탭 히어로가 쓴다). 사용처가 하나도 없어도 **지우지 않는다** — 이번 작업 범위 밖이다.

- [ ] **Step 6: analyze + 커밋**

```bash
flutter analyze
flutter test
git add -A
git commit -m "feat(settings): 도장 모양을 한 줄로 줄이고 선택은 시트로 보낸다"
```

---

### Task 6: AI 자동화 섹션 제거

**Files:**
- Delete: `lib/features/settings/presentation/widgets/ai_task_share_tile.dart`
- Modify: `lib/features/settings/presentation/screens/settings_screen.dart`
- Modify: `lib/core/constants/strings/settings_strings.dart`
- Modify: `test/tools/visual_check.dart`

**Interfaces:**
- Produces: 없음 (제거만)

**선행 조건 (충족됨):** 사용자가 실기기에서 `AI로 보내기` 토글을 껐다고 확인함(2026-07-30).
켜진 채로 제거하면 `event_edit_dialog.dart`가 provider를 계속 watch해 끌 방법이 없어진다.

- [ ] **Step 1: 남길 것을 확인한다**

Run: `grep -rn "aiTaskShareEnabledProvider" lib/`
`ai_task_share_provider.dart`(정의)와 `event_edit_dialog.dart`(watch) 둘만 남아야 한다.
**이 둘은 지우지 않는다** — provider까지 지우면 되살릴 때 저장값을 버린다.

- [ ] **Step 2: 설정 화면에서 섹션을 뺀다**

`lib/features/settings/presentation/screens/settings_screen.dart`:

`import '../widgets/ai_task_share_tile.dart';` 를 지운다.

아래 블록을 통째로 지운다:

```dart
          const SettingsSection(
            title: SettingsStrings.aiShareSection,
            subtitle: SettingsStrings.aiShareDescription,
            child: AiTaskShareTile(),
          ),
```

- [ ] **Step 3: 위젯 파일과 문자열을 지운다**

```bash
rm lib/features/settings/presentation/widgets/ai_task_share_tile.dart
```

`lib/core/constants/strings/settings_strings.dart`에서 아래 5개를 지운다:

```dart
  static const aiShareSection = 'AI 자동화 (고급)';

  // AI 자동화 공유 (고급)
  static const aiShareDescription = '캘린더 일정을 외부 AI로 보내 문서 초안·준비 정리 등을 맡깁니다';
  static const aiShareToggleTitle = 'AI로 보내기 활성화';
  static const aiShareToggleSubtitle = '켜면 캘린더 일정 편집에 "AI로 보내기"가 나타납니다 (기본 꺼짐)';
```

- [ ] **Step 4: `visual_check.dart`의 참조를 뺀다**

`test/tools/visual_check.dart:727` 부근의 `AiTaskShareTile` 항목을 지운다.
이 파일은 `_test` 접미사가 없어 `flutter test` 자동 스캔에서 빠지지만,
`flutter analyze`는 본다.

- [ ] **Step 5: 남은 참조가 없는지 본다**

```bash
grep -rn "AiTaskShareTile\|aiShare" lib/ test/ integration_test/
```
Expected: 결과 없음. (`aiTaskShareEnabledProvider`는 다른 이름이라 안 걸린다.)

- [ ] **Step 6: analyze + test + 커밋**

```bash
flutter analyze
flutter test
git add -A
git commit -m "feat(settings): AI 자동화 섹션을 내린다 (provider는 남긴다)"
```

---

### Task 7: 전체 검증

**Files:** 없음 (검증만)

- [ ] **Step 1: 전체 정적 분석**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: 전체 테스트**

Run: `flutter test`
Expected: 전부 통과. 기존 825건 + 신규 15건 안팎.

실패하면 **그 실패를 고치기 전에 원인을 적는다.** 특히
`bus_settings_tiles_test.dart` 9건이 깨졌다면 위젯을 건드린 것이므로 되돌린다.

- [ ] **Step 3: 시뮬레이터로 눈으로 본다**

```bash
flutter run -d "iPhone 16 Pro"
```

확인 항목:
1. 설정 탭 — `도장 모양`이 **한 줄**이고 오른쪽에 현재 이름(`완료`)이 보인다.
2. 그 줄을 누르면 시트가 올라오고 **도장 네 개가 그림으로** 보인다.
   특히 **도마뱀**(PNG 알파 마스크)이 빈 칸이 아니어야 한다 — 위젯 존재 검증만으로는
   못 지키는 자리다.
3. 하나 고르면 시트가 닫히고 설정 줄의 이름이 바뀐다.
4. `버스 도착`이 한 줄이고 `꺼짐`이 보인다. 누르면 화면이 열리고 탭바가 남아 있다.
5. 그 화면에서 표시를 켜고 `출발지`를 눌러 정류장 검색까지 들어갔다가
   **뒤로가기 두 번**으로 설정 탭까지 돌아온다.
6. `AI 자동화` 섹션이 없다.
7. 다크/라이트 both — 설정 탭 최상단에서 테마를 바꿔 시트와 화면을 다시 본다.

- [ ] **Step 4: 배포**

analyze + test가 green이고 시뮬레이터 확인이 끝나면 (CLAUDE.md 배포 정책):

```bash
./ios/bin/fastlane.sh beta
```

전문 로그를 남긴다(`tail` 파이프 금지 — exit 0이 tail의 것이 된다).
업로드 3분 뒤 `./ios/bin/fastlane.sh check_builds`로 VALID를 확인한다.

- [ ] **Step 5: push**

```bash
git push -u origin feat/settings-ia
```

---

## Self-Review

**1. 스펙 커버리지**

| 스펙 요구 | Task |
|---|---|
| 도장 모양 한 줄 + 현재값 | 5 |
| 2열 그리드 시트, `CompletionSeal` 재사용 | 4 |
| 선택 표시 = 색 + 체크 | 4 (테스트로 고정) |
| 고르면 즉시 저장·닫힘 | 4 |
| `useSafeArea: true` | 4 |
| 주석 규칙 "늘어나면 시트"로 갱신 | 4·5 (양쪽 파일) |
| 버스 상세 화면 + ShellRoute | 2 |
| `BusSettingsTiles` 무수정 | 2·3 (Step 6에서 확인) |
| 섹션 부제를 화면으로 이동 | 2 (테스트로 고정) |
| `buildBusSettingsSummary` 순수 함수 4분기 | 1 (5건 — 꺼짐+정류장 있음 케이스 추가) |
| 정류장 이름 대신 개수 | 1 |
| AI 섹션 제거, provider 유지 | 6 |
| `SealStyle.values` 전부 렌더 가드 | 4 |
| 시뮬레이터 확인(도마뱀 에셋) | 7 |

빠진 요구 없음.

**2. 플레이스홀더 스캔**

"적절히", "TBD", "필요하면 처리" 없음. 모든 코드 단계에 실제 코드가 있다.
Task 4 Step 5와 Task 5 Step 5는 확인 단계이지 미정 사항이 아니다.

**3. 타입 일관성**

- `buildBusSettingsSummary(BusSettings) → String` — Task 1 정의, Task 3 사용. 일치.
- `AppRoutes.busSettings` — Task 2 정의, Task 3 사용. 일치.
- `StampStyleSheet.show(BuildContext) → Future<void>` — Task 4 정의, Task 5 사용. 일치.
- `StampStyleSheet.optionKey(SealStyle) → Key` — Task 4 정의, Task 4 테스트 사용. 일치.
- `StampSettingsTiles.styleTileKey` — Task 5 정의, Task 5 테스트 사용. 일치.
- `BusSummaryListTile.tileKey` — Task 3 정의, Task 3 테스트 사용. 일치.

**4. 알려진 위험**

- Task 4의 `AppColors.surface`·`line`·`ink`·`faint` 존재 여부는 Step 5에서 확인한다.
  없으면 있는 토큰으로 바꾼다(새 토큰 금지 — 전역 영향).
- Task 1의 `BusStop` 생성자 인자 이름은 Step 3에서 확인한다.
- `_Option`의 `Row` 첫 자식 `SizedBox.shrink()`는 불필요하다 — 구현 시 지운다.
