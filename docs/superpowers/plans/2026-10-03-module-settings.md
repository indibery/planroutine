# 기능별 설정을 기능 관리 안으로 — 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 설정 탭에서 `버스 도착` 행을 없애고, `기능 관리`의 버스 행에서 켜고 끄며 켜져 있을 때 `›`로 상세 설정에 들어가게 한다. 버스 상세 화면의 켜짐 스위치를 없앤다.

**Architecture:** 등록부 항목(`AppModule`)이 상세 화면 경로(`settingsRoute`)와 켜진 행의 부제 위젯(`settingsSummary`)을 선언한다. `ModulesScreen`은 그 둘만 보고 행을 그린다 — 버스의 내부 상태를 모른다. 버스 요약은 `features/bus/`의 작은 ConsumerWidget(`BusModuleSummary`)이 그린다.

**Tech Stack:** Flutter 3.44.8 / Dart 3.12.2, Riverpod 2.6.1, GoRouter(ShellRoute), shared_preferences, flutter_test

**Spec:** `docs/superpowers/specs/2026-10-03-module-settings-design.md`

## Global Constraints

- **설정 탭에는 앱 공통 설정과 고정 탭의 설정만 둔다. 선택 기능의 설정 행은 만들지 않는다.**
- 기능별 설정은 `기능 관리` › 그 기능의 행 › 상세 화면. **켜져 있을 때만** 들어간다(꺼져 있으면 `›`가 없고 행을 눌러도 이동하지 않는다).
- **켜고 끄는 스위치는 기능 관리 행에 하나뿐이다.** 상세 화면에는 켜짐 스위치를 두지 않는다.
- 상세 설정이 없는 기능은 `settingsRoute`가 null이고 `›`도 없다.
- 처음 켰는데 설정이 비어 있으면 화면을 옮기지 않고 행 부제로 다음 행동을 알린다.
- 버스 요약 문구: 정류장 0곳 → `정류장을 등록해 주세요`, N곳 → `정류장 N곳`.
- `/bus/settings` 라우트와 저장 형식(`bus_settings_v1`)은 바꾸지 않는다. push 주인 탭은 설정 그대로.
- Riverpod만 쓴다. 문자열은 `*Strings`, 색은 `AppColors`, 크기는 `AppSizes`. 한글 UI·한글 주석. `!` 강제 언래핑 금지.
- 스위치에 `activeThumbColor`를 주지 않는다(전역 `switchTheme` 색 가드).
- **기존 테스트를 지우지 않는다.** 파일별 `test(`/`testWidgets(`/`group(` 선언 수가 줄면 `protect-tests.sh` 훅이 막는다. 같은 의도를 새 구조로 다시 겨눈다.
- **`rm`/`git rm`으로 `lib/`·`test/` 파일을 지우지 않는다**(훅이 막는다). 파일을 옮길 때는 `git mv`를 쓴다.
- 아이폰 단축어(App Intents) 코드와 가드는 건드리지 않는다.

## Review Focus

1. **켜진 행에서 스위치를 누르면 상세로 넘어가 버리는 제스처 충돌** — 스위치는 켜고 끄기만 해야 한다. → Task 3 `스위치를 눌러도 이동하지 않는다`.
1-1. **켤 때 `›`가 생기며 스위치가 옆으로 밀리는 것** — 누른 스위치가 손가락 아래에서 움직이면 안 된다. → Task 3의 `› 자리 비워 두기` + 기존 테스트 `켜고 꺼도 같은 자리에 머문다`(스위치 rect를 잰다)가 그대로 지킨다.
2. **320pt에서 스위치 + `›` + 요약이 한 행에 들어갈 때 넘침** — → Task 3에서 폭 테스트가 버스를 켠 상태도 훑게 한다.
3. **상세 화면에서 정류장을 바꾸고 돌아왔을 때 요약이 옛 값으로 남는 것** — → Task 2 `정류장이 바뀌면 요약도 바뀐다`.
4. **끄고 나서 `›`가 남아 꺼진 기능의 상세로 들어갈 수 있는 것** — → Task 3 `끄면 ›가 사라진다`.
5. **설정 탭에 기능 행이 다시 생기는 회귀**(다음 기능을 만들 때 습관적으로 설정 탭에 행을 추가) — → Task 2 `settings_tab_module_rows_test.dart`.

---

## 파일 구조

| 파일 | 역할 | 작업 |
|---|---|---|
| `lib/core/modules/app_module.dart` | `settingsRoute`·`settingsSummary` 필드 | Modify |
| `lib/core/modules/module_catalog.dart` | 버스 항목에 두 필드 | Modify |
| `lib/features/bus/domain/bus_settings_summary.dart` | `installed` 인자·`꺼짐` 갈래 제거 | Modify |
| `lib/features/bus/presentation/widgets/bus_module_summary.dart` | 켜진 버스 행의 부제 | Create(`git mv`로 `bus_summary_list_tile.dart`에서) |
| `lib/features/settings/presentation/screens/settings_screen.dart` | 버스 행 제거 | Modify |
| `lib/features/settings/presentation/screens/modules_screen.dart` | 행 = 스위치 + `›` + 요약, 행 탭 → 상세 | Modify |
| `lib/features/settings/presentation/widgets/bus_settings_tiles.dart` | 켜짐 스위치 제거, 줄 항상 표시 | Modify |
| `lib/features/settings/presentation/screens/bus_settings_screen.dart` | 제목 = 기능 이름 | Modify |
| `lib/features/settings/presentation/widgets/modules_list_tile.dart` | 주석의 `BusSummaryListTile` 언급 | Modify |
| `lib/core/constants/strings/bus_strings.dart` | 요약 문구 변경, 안 쓰는 문자열 제거 | Modify |
| `test/tools/visual_check.dart` | `BusStrings.section` → `moduleName` | Modify |
| `test/features/bus/bus_module_summary_test.dart` | `git mv`로 `test/features/settings/bus_summary_list_tile_test.dart`에서 | Create |
| `test/features/settings/settings_tab_module_rows_test.dart` | 설정 탭 회귀 가드 | Create |

---

### Task 1: 등록부 항목에 상세 경로와 요약 자리를 둔다

**Files:**
- Modify: `lib/core/modules/app_module.dart` (`AppModule`)
- Modify: `lib/core/modules/module_catalog.dart` (버스 항목)
- Test: `test/core/modules/module_catalog_test.dart`

**Interfaces:**
- Produces:
  - `AppModule.settingsRoute` (`String?`) — 상세 화면 경로. null이면 상세가 없다.
  - `AppModule.settingsSummary` (`Widget?`) — 켜진 행의 부제. null이면 `description`을 쓴다.
  - 버스 항목 `settingsRoute: AppRoutes.busSettings` (요약 위젯은 Task 2에서 단다)

- [ ] **Step 1: 실패하는 테스트 작성**

`test/core/modules/module_catalog_test.dart`의 `탭형 기능의 라우트는 …` 테스트 바로 뒤에 추가한다.

```dart
  test('상세 설정 경로는 설치 여부와 무관하게 라우터에 있다', () {
    final paths = _paths(createRouter(onboardingDone: true).configuration.routes);
    final routes = [
      for (final m in moduleCatalog)
        if (m.settingsRoute case final route?) route,
    ];
    // 버스가 상세를 가지므로 비면 안 된다 — 비면 아래 루프가 아무것도 검사하지 않는다.
    expect(routes, isNotEmpty);
    for (final route in routes) {
      expect(paths, contains(route), reason: '$route가 없으면 ›를 눌렀을 때 Page Not Found');
    }
  });

  test('고정 기능은 상세 경로를 갖지 않는다 — 고정 탭의 설정은 설정 탭에 있다', () {
    for (final m in moduleCatalog.where((m) => m.fixed)) {
      expect(m.settingsRoute, isNull, reason: m.id);
      expect(m.settingsSummary, isNull, reason: m.id);
    }
  });
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/core/modules/module_catalog_test.dart`
Expected: FAIL — `settingsRoute`·`settingsSummary` getter가 없어 컴파일 오류

- [ ] **Step 3: 구현**

`app_module.dart`의 `AppModule` 생성자와 필드에 더한다(기존 필드는 그대로):

```dart
class AppModule {
  const AppModule({
    required this.id,
    required this.name,
    required this.icon,
    required this.placement,
    this.description = '',
    this.fixed = false,
    this.tab,
    this.card,
    this.settingsRoute,
    this.settingsSummary,
  });
```

`card` 필드 아래에:

```dart
  /// 상세 설정 화면 경로. **켜져 있을 때만** `기능 관리`의 이 행에서 `›`로 들어간다.
  /// null이면 상세가 없다. 설정 탭에는 이 경로로 가는 행을 두지 않는다
  /// (`settings_tab_module_rows_test.dart`가 지킨다).
  final String? settingsRoute;

  /// 켜진 행의 부제 — 기능이 스스로 상태를 요약한다(예: 정류장 2곳). null이면
  /// [description]을 쓴다. 위젯으로 두는 이유는 [card]와 같다: 기능 관리 화면이
  /// 각 기능의 내부 상태를 몰라도 된다.
  final Widget? settingsSummary;
```

`module_catalog.dart`의 버스 항목에 한 줄을 더한다(`card:` 다음):

```dart
    settingsRoute: AppRoutes.busSettings,
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/core/modules/ && flutter analyze`
Expected: PASS, `No issues found!`

- [ ] **Step 5: 커밋**

```bash
git add lib/core/modules/app_module.dart lib/core/modules/module_catalog.dart test/core/modules/module_catalog_test.dart
git commit -m "feat(modules): 등록부 항목이 상세 설정 경로와 요약 자리를 선언한다"
```

---

### Task 2: 버스 요약을 기능이 그리고, 설정 탭에서 버스 행을 뺀다

**Files:**
- Modify: `lib/features/bus/domain/bus_settings_summary.dart`
- Modify: `lib/core/constants/strings/bus_strings.dart` (요약 문구)
- Move+Rewrite: `lib/features/settings/presentation/widgets/bus_summary_list_tile.dart` → `lib/features/bus/presentation/widgets/bus_module_summary.dart`
- Move+Rewrite: `test/features/settings/bus_summary_list_tile_test.dart` → `test/features/bus/bus_module_summary_test.dart`
- Modify: `lib/core/modules/module_catalog.dart` (`settingsSummary`)
- Modify: `lib/features/settings/presentation/screens/settings_screen.dart`
- Modify: `lib/features/settings/presentation/widgets/modules_list_tile.dart` (주석 한 줄)
- Test: `test/features/bus/bus_settings_summary_test.dart`, `test/features/settings/settings_tab_module_rows_test.dart`(신규)

**Interfaces:**
- Consumes: Task 1의 `AppModule.settingsRoute`·`settingsSummary`
- Produces:
  - `String buildBusSettingsSummary(BusSettings settings)` (인자 하나)
  - `class BusModuleSummary extends ConsumerWidget` (`const BusModuleSummary({super.key})`) — `lib/features/bus/presentation/widgets/bus_module_summary.dart`
  - `BusStrings.summaryNoStop = '정류장을 등록해 주세요'`, `BusStrings.summaryStops(int n) => '정류장 $n곳'`. `BusStrings.summaryOff`는 지운다.

- [ ] **Step 1: 파일 옮기기 (내용은 다음 단계에서 바꾼다)**

```bash
git mv lib/features/settings/presentation/widgets/bus_summary_list_tile.dart lib/features/bus/presentation/widgets/bus_module_summary.dart
git mv test/features/settings/bus_summary_list_tile_test.dart test/features/bus/bus_module_summary_test.dart
```

- [ ] **Step 2: 요약 순수 함수 테스트를 다시 겨눈다**

`test/features/bus/bus_settings_summary_test.dart`의 `main`을 아래로 바꾼다(선언 6개 유지 — group 1 + test 5). `_stop` 헬퍼와 import는 그대로 둔다.

```dart
void main() {
  group('buildBusSettingsSummary — 켜진 행의 부제', () {
    test('정류장이 없으면 등록하라고 말한다', () {
      // 처음 켠 사람에게 다음 행동을 알린다 — 화면을 옮기지 않으므로 이 한 줄이 안내다.
      expect(
        buildBusSettingsSummary(BusSettings.defaults),
        BusStrings.summaryNoStop,
      );
    });

    test('요약은 켜짐·꺼짐을 말하지 않는다 — 그건 스위치가 말한다', () {
      // 요약은 켜진 행에만 쓰인다. `켜짐 · 2곳`처럼 상태를 다시 적으면 바로 옆
      // 스위치와 같은 말을 두 번 한다.
      final both = BusSettings.defaults.copyWith(
        departure: _stop('우방아파트'),
        arrival: _stop('중앙공원'),
      );
      for (final s in [BusSettings.defaults, both]) {
        final text = buildBusSettingsSummary(s);
        expect(text, isNot(contains('켜짐')));
        expect(text, isNot(contains('꺼짐')));
      }
    });

    test('한 곳만 등록하면 1곳', () {
      final settings = BusSettings.defaults.copyWith(
        departure: _stop('우방아파트'),
      );
      expect(buildBusSettingsSummary(settings), BusStrings.summaryStops(1));
    });

    test('두 곳을 등록하면 2곳', () {
      final settings = BusSettings.defaults.copyWith(
        departure: _stop('우방아파트'),
        arrival: _stop('중앙공원'),
      );
      expect(buildBusSettingsSummary(settings), BusStrings.summaryStops(2));
    });

    test('도착지만 등록해도 1곳이다', () {
      final settings = BusSettings.defaults.copyWith(
        arrival: _stop('중앙공원'),
      );
      expect(buildBusSettingsSummary(settings), BusStrings.summaryStops(1));
    });
  });
}
```

- [ ] **Step 3: 요약 위젯 테스트를 다시 쓴다**

`test/features/bus/bus_module_summary_test.dart` 전체를 아래로 바꾼다(선언 2 → 3, 줄지 않는다).

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/bus/domain/bus_settings.dart';
import 'package:planroutine/features/bus/domain/bus_stop.dart';
import 'package:planroutine/features/bus/domain/commute_direction.dart';
import 'package:planroutine/features/bus/presentation/providers/bus_providers.dart';
import 'package:planroutine/features/bus/presentation/widgets/bus_module_summary.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/module_prefs.dart';

const _stop = BusStop(
  nodeId: 'GGB201000156',
  nodeNm: '서울역버스환승센터',
  nodeNo: 2004,
  cityCode: 0,
);

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(home: Scaffold(body: BusModuleSummary())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('정류장이 없으면 등록 안내가 보인다', (tester) async {
    SharedPreferences.setMockInitialValues(modulePrefs());
    await _pump(tester);
    expect(find.text(BusStrings.summaryNoStop), findsOneWidget);
  });

  testWidgets('정류장을 등록해 두었으면 개수가 보인다', (tester) async {
    SharedPreferences.setMockInitialValues(
      modulePrefs(bus: BusSettings.defaults.copyWith(departure: _stop)),
    );
    await _pump(tester);
    expect(find.text(BusStrings.summaryStops(1)), findsOneWidget);
  });

  testWidgets('정류장이 바뀌면 요약도 바뀐다 — 상세에서 돌아왔을 때 옛 값이 남지 않는다', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(modulePrefs());
    await _pump(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BusModuleSummary)),
    );
    await container
        .read(busSettingsProvider.notifier)
        .setStop(CommuteDirection.toWork, _stop);
    await tester.pumpAndSettle();
    expect(find.text(BusStrings.summaryStops(1)), findsOneWidget);
  });
}
```

> `setStop(CommuteDirection, BusStop)`은 `integration_test/screenshot_test.dart`가 이미 같은 모양으로 부른다. 시그니처가 다르면 `bus_providers.dart`를 읽고 맞춘다 — 테스트의 의도(바꾸면 요약이 따라온다)는 그대로 둔다.

- [ ] **Step 4: 설정 탭 회귀 가드 작성**

`test/features/settings/settings_tab_module_rows_test.dart`를 새로 만든다.

```dart
// 설정 탭에는 앱 공통 설정과 고정 탭의 설정만 둔다. 선택 기능의 설정은
// `기능 관리` › 그 기능의 행으로만 들어간다(2026-10-03 설계).
//
// 다음 기능을 만들 때 습관적으로 설정 탭에 행을 추가하면 이 가드가 막는다.
// **주석은 걷어내고 본다** — 이 리포는 "언급을 사용으로 읽는" 스캐너 함정을
// 다섯 번 밟았다(CLAUDE.md 훅 절).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/modules/module_catalog.dart';

String _code(File f) => f
    .readAsLinesSync()
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

/// `AppRoutes`의 `static const 이름 = '경로';`를 이름 → 경로로 읽는다.
Map<String, String> _appRoutes() {
  final src = File('lib/core/router/app_router.dart').readAsStringSync();
  return {
    for (final m in RegExp(
      r"static const (\w+) = '([^']+)';",
    ).allMatches(src))
      m.group(1) ?? '': m.group(2) ?? '',
  };
}

/// 설정 탭을 이루는 파일들 — 화면 하나와 그 섹션 위젯들.
List<File> _settingsTabFiles() => [
  File('lib/features/settings/presentation/screens/settings_screen.dart'),
  ...Directory('lib/features/settings/presentation/widgets')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart')),
];

void main() {
  test('설정 탭은 선택 기능의 상세 설정으로 직접 가지 않는다 — 입구는 기능 관리', () {
    final targets = {
      for (final m in moduleCatalog)
        if (m.settingsRoute case final r?) r,
    };
    final names = [
      for (final e in _appRoutes().entries)
        if (targets.contains(e.value)) e.key,
    ];
    expect(names, isNotEmpty, reason: '등록부의 상세 경로를 AppRoutes에서 찾지 못했다');

    for (final f in _settingsTabFiles()) {
      final src = _code(f);
      for (final n in names) {
        expect(
          src.contains('AppRoutes.$n'),
          isFalse,
          reason: '${f.path}가 AppRoutes.$n로 간다 — 선택 기능의 설정은 기능 관리 안에서 연다',
        );
      }
    }
  });

  test('설정 탭은 선택 기능의 요약 위젯을 그리지 않는다', () {
    final types = [
      for (final m in moduleCatalog)
        if (m.settingsSummary case final w?) w.runtimeType.toString(),
    ];
    expect(types, isNotEmpty, reason: '요약 위젯을 가진 기능이 없다');

    final src = _code(
      File('lib/features/settings/presentation/screens/settings_screen.dart'),
    );
    for (final t in types) {
      expect(src.contains(t), isFalse, reason: '설정 탭에 $t가 다시 들어왔다');
    }
  });
}
```

- [ ] **Step 5: 실패 확인**

Run: `flutter test test/features/bus/bus_settings_summary_test.dart test/features/bus/bus_module_summary_test.dart test/features/settings/settings_tab_module_rows_test.dart`
Expected: FAIL — `buildBusSettingsSummary`에 `installed` 인자가 남아 있고 `BusModuleSummary`가 없다(컴파일 오류)

- [ ] **Step 6: 구현 — 문자열**

`bus_strings.dart`의 `// ── 설정 탭 요약 한 줄 ──` 블록을 아래로 바꾼다(`summaryOff` 삭제).

```dart
  // ── 기능 관리 행 요약 ─────────────────────────────────────
  /// 켜진 버스 행의 부제. 켜짐·꺼짐은 바로 옆 스위치가 말하므로 여기 적지 않는다.
  ///
  /// **정류장 이름을 넣지 않는다.** `우방아파트→중앙공원`은 320pt에서 넘친다.
  /// 이름은 상세 화면 안에서 본다.
  static const summaryNoStop = '정류장을 등록해 주세요';
  static String summaryStops(int n) => '정류장 $n곳';
```

- [ ] **Step 7: 구현 — 순수 함수**

`bus_settings_summary.dart` 전체:

```dart
import '../../../core/constants/app_strings.dart';
import 'bus_settings.dart';

/// `기능 관리`의 켜진 버스 행 부제.
///
/// 순수 함수로 둔다 — 이 리포가 요약 문구를 다루는 방식이다
/// (`buildBusCardView`·`buildTodayView`·`computeNotifications`). 위젯 안에서
/// 조립하면 분기를 유닛 테스트로 고정할 수 없다.
///
/// 켜짐 여부는 보지 않는다 — **켜진 행에만** 쓰인다(꺼진 행은 기능 설명을 보인다).
String buildBusSettingsSummary(BusSettings settings) {
  var count = 0;
  if (settings.departure != null) count++;
  if (settings.arrival != null) count++;

  if (count == 0) return BusStrings.summaryNoStop;
  return BusStrings.summaryStops(count);
}
```

- [ ] **Step 8: 구현 — 요약 위젯**

`lib/features/bus/presentation/widgets/bus_module_summary.dart` 전체:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/bus_settings.dart';
import '../../domain/bus_settings_summary.dart';
import '../providers/bus_providers.dart';

/// `기능 관리`의 켜진 버스 행 부제. 등록부(`moduleCatalog`)가 이 위젯을 들고 있다.
///
/// 글자 모양은 지정하지 않는다 — `ListTile` 부제 자리의 기본 스타일을 따라야 다른
/// 기능의 부제(설명 문구)와 같아 보인다.
///
/// **로딩 중에도 기본값으로 그린다.** null에 빈 위젯을 돌려주면
/// `SharedPreferences.getInstance()`를 기다리는 한 프레임 동안 부제가 비어 행 높이가 튄다.
class BusModuleSummary extends ConsumerWidget {
  const BusModuleSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(busSettingsProvider).valueOrNull ?? BusSettings.defaults;
    return Text(buildBusSettingsSummary(settings));
  }
}
```

- [ ] **Step 9: 구현 — 등록부와 설정 탭**

`module_catalog.dart`: import에 `import '../../features/bus/presentation/widgets/bus_module_summary.dart';`를 더하고, 버스 항목의 `settingsRoute:` 다음 줄에 `settingsSummary: BusModuleSummary(),`를 더한다.

`settings_screen.dart`: `const SettingsSection(child: BusSummaryListTile()),` 줄과 `bus_summary_list_tile.dart` import를 지운다.

`modules_list_tile.dart` 12행 주석 `모양은 \`BusSummaryListTile\`과 같다`를 `모양은 \`TrashListTile\`과 같다`로 바꾼다(그 위젯이 같은 모양 — 아이콘 + 제목 + 현재 상태 + chevron — 이다. 다르면 analyze가 아니라 눈으로 확인하고 맞는 이름을 쓴다).

- [ ] **Step 10: 통과 확인**

Run: `flutter test test/features/bus/ test/features/settings/ test/core/modules/ && flutter analyze`
Expected: PASS, `No issues found!`. `test/tools/visual_check.dart`가 `BusSummaryListTile`을 참조하면 analyze가 잡는다 — 그 줄을 지우지 말고 `BusModuleSummary`로 바꾼다.

- [ ] **Step 11: 커밋**

```bash
git add -A lib/features/bus lib/features/settings lib/core test/features/bus test/features/settings
git commit -m "feat(modules): 버스 요약을 기능이 그리고 설정 탭에서 버스 행을 뺀다"
```

(`git add -A`는 위 경로로만 한정한다 — `git mv`로 옮긴 파일의 삭제·추가를 함께 담기 위해서다. `docs/community/`는 담지 않는다.)

---

### Task 3: 기능 관리 행 — 스위치 + `›` + 요약, 행 탭으로 상세

**Files:**
- Modify: `lib/features/settings/presentation/screens/modules_screen.dart` (`_moduleTile`, 키 둘 추가)
- Test: `test/features/settings/modules_screen_test.dart`

**Interfaces:**
- Consumes: `AppModule.settingsRoute`·`settingsSummary`(Task 1), 버스 항목의 `BusModuleSummary`(Task 2), `AppRoutes.busSettings`
- Produces: `ModulesScreen.rowKey(String id)`, `ModulesScreen.chevronKey(String id)`. `switchKey(id)`는 이제 **`Switch` 위젯**에 붙는다(전에는 `SwitchListTile`).

- [ ] **Step 1: 실패하는 테스트로 바꾸고 더한다**

`test/features/settings/modules_screen_test.dart`:

(a) import에 더한다:

```dart
import 'package:go_router/go_router.dart';
import 'package:planroutine/core/router/app_router.dart';
```

`package:planroutine/features/settings/presentation/widgets/bus_settings_tiles.dart` import는 지운다(이 파일이 더 쓰지 않는다).

(b) `_pump` 아래에 라우터를 단 헬퍼를 더한다:

```dart
/// 행을 눌렀을 때의 이동을 보려고 라우터를 단다. 상세 화면 자리에는 표식만 둔다.
Future<void> _pumpRouted(
  WidgetTester tester, {
  List<String> installed = const [],
}) async {
  SharedPreferences.setMockInitialValues(modulePrefs(installed: installed));
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const ModulesScreen()),
      GoRoute(
        path: AppRoutes.busSettings,
        builder: (_, _) => const Scaffold(body: Text('버스상세')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [moduleCatalogProvider.overrideWithValue(_catalog)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}
```

(c) `탭이 6개면 …` 테스트의 `tester.widget<SwitchListTile>(` 세 곳을 `tester.widget<Switch>(`로 바꾼다(단정은 그대로 `onChanged`).

(d) `버스 상세 스위치와 기능 관리 스위치가 같은 값을 본다` 테스트를 **지우지 않고** 아래로 바꾼다(스위치가 기능 관리에만 남으므로 "같은 값" 대신 "꺼진 행은 상세로 가지 않는다"를 지킨다):

```dart
  testWidgets('꺼진 기능 행에는 ›가 없고 눌러도 상세로 가지 않는다', (tester) async {
    await _pumpRouted(tester);
    expect(find.byKey(ModulesScreen.chevronKey(ModuleIds.bus)), findsNothing);
    await tester.tap(find.byKey(ModulesScreen.rowKey(ModuleIds.bus)));
    await tester.pumpAndSettle();
    expect(find.text('버스상세'), findsNothing);
  });
```

(e) 그 바로 뒤에 새 테스트 넷을 더한다:

```dart
  testWidgets('켜면 ›가 생기고 부제가 기능의 요약으로 바뀐다', (tester) async {
    await _pumpRouted(tester);
    expect(find.text(BusStrings.summaryNoStop), findsNothing);
    await tester.tap(find.byKey(ModulesScreen.switchKey(ModuleIds.bus)));
    await tester.pumpAndSettle();
    expect(find.byKey(ModulesScreen.chevronKey(ModuleIds.bus)), findsOneWidget);
    // 정류장이 없으니 다음 행동을 알린다 — 화면은 옮기지 않는다
    expect(find.text(BusStrings.summaryNoStop), findsOneWidget);
    expect(find.text('버스상세'), findsNothing);
  });

  testWidgets('켜진 행을 누르면 상세 설정 화면으로 간다', (tester) async {
    await _pumpRouted(tester, installed: [ModuleIds.bus]);
    await tester.tap(find.byKey(ModulesScreen.rowKey(ModuleIds.bus)));
    await tester.pumpAndSettle();
    expect(find.text('버스상세'), findsOneWidget);
  });

  testWidgets('스위치를 눌러도 상세로 가지 않는다 — 스위치는 켜고 끄기만 한다', (tester) async {
    await _pumpRouted(tester, installed: [ModuleIds.bus]);
    await tester.tap(find.byKey(ModulesScreen.switchKey(ModuleIds.bus)));
    await tester.pumpAndSettle();
    expect(find.text('버스상세'), findsNothing);
    // 그리고 실제로 꺼졌다 — ›도 함께 사라진다
    expect(tester.widget<Switch>(find.byKey(ModulesScreen.switchKey(ModuleIds.bus))).value, isFalse);
    expect(find.byKey(ModulesScreen.chevronKey(ModuleIds.bus)), findsNothing);
  });

  testWidgets('상세 설정이 없는 기능은 켜도 ›가 없고 눌러도 이동하지 않는다', (tester) async {
    // t1은 settingsRoute가 없는 테스트용 탭형 기능이다
    await _pumpRouted(tester, installed: ['t1']);
    expect(find.byKey(ModulesScreen.chevronKey('t1')), findsNothing);
    await tester.tap(find.byKey(ModulesScreen.rowKey('t1')));
    await tester.pumpAndSettle();
    expect(find.byType(ModulesScreen), findsOneWidget);
  });
```

(f) 맨 아래 폭 루프의 `installed: ['t1', 't2']`를 `installed: ['t1', 't2', ModuleIds.bus]`로 바꾼다 — 스위치 + `›` + 요약이 한 행에 들어간 상태로 320pt를 훑는다(Review Focus 2).

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/settings/modules_screen_test.dart`
Expected: FAIL — `rowKey`·`chevronKey`가 없다(컴파일 오류)

- [ ] **Step 3: 구현**

`modules_screen.dart`:

import에 `import 'package:go_router/go_router.dart';`를 더한다.

키 아래에 둘을 더한다:

```dart
  static Key rowKey(String id) => Key('module_row_$id');
  static Key chevronKey(String id) => Key('module_chevron_$id');

  /// `Icons.chevron_right`의 기본 크기(24)와 같다 — 꺼진 행의 빈 자리.
  static const _chevronSlot = 24.0;
```

클래스 주석 끝에 한 문단을 더한다:

```dart
///
/// **켜진 기능의 상세 설정은 여기서만 연다**(2026-10-03 설계). 행을 누르면 그 기능의
/// `settingsRoute`로 가고, 스위치는 켜고 끄기만 한다. 설정 탭에는 기능별 행이 없다.
```

`build` 안의 `_moduleTile(` 호출에 `context,`를 첫 인자로 넘긴다.

`_moduleTile` 전체를 아래로 바꾼다:

```dart
  /// 스위치에 `activeThumbColor`를 주지 않는다 — 전역 `switchTheme` 색 가드.
  ///
  /// 행과 스위치가 맡는 일이 다르다: **행을 누르면 상세로, 스위치를 누르면 켜고 끄기.**
  /// 그래서 `SwitchListTile`(행 전체가 스위치)을 쓰지 않는다.
  Widget _moduleTile(
    BuildContext context,
    AppModule m, {
    required bool installed,
    required bool blocked,
    required ValueChanged<bool> onChanged,
  }) {
    final placement = m.placement == ModulePlacement.tab
        ? SettingsStrings.placementTab
        : SettingsStrings.placementTodayCard;
    // 꺼져 있으면 상세로 가지 않는다 — 꺼진 기능의 설정을 고칠 이유가 없다.
    final route = installed ? m.settingsRoute : null;
    final summary = installed ? m.settingsSummary : null;
    return ListTile(
      key: rowKey(m.id),
      leading: Icon(m.icon, color: AppColors.primary),
      title: Text(m.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          summary ?? Text('$placement · ${m.description}'),
          if (blocked) Text(SettingsStrings.modulesTabsFull(kMaxTabs)),
        ],
      ),
      isThreeLine: blocked,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            key: switchKey(m.id),
            value: installed,
            onChanged: blocked ? null : onChanged,
          ),
          // 상세가 있는 기능은 꺼져 있어도 › 자리를 비워 둔다. 켤 때 ›가 새로 생기면
          // Row가 넓어져 **방금 누른 스위치가 손가락 아래에서 왼쪽으로 밀린다**.
          if (route != null)
            Icon(Icons.chevron_right, key: chevronKey(m.id))
          else if (m.settingsRoute != null)
            const SizedBox(width: _chevronSlot),
        ],
      ),
      onTap: route == null ? null : () => context.push(route),
    );
  }
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/features/settings/ test/features/bus/ && flutter analyze`
Expected: PASS, `No issues found!`. `test/features/bus/bus_settings_tiles_test.dart`의 스위치 색 테스트는 아직 `BusSettingsTiles`의 스위치를 보므로 그대로 통과해야 한다(Task 4에서 옮긴다).

- [ ] **Step 5: 커밋**

```bash
git add lib/features/settings/presentation/screens/modules_screen.dart test/features/settings/modules_screen_test.dart
git commit -m "feat(modules): 기능 관리 행에서 켜고 끄고, 켜져 있으면 상세 설정으로 들어간다"
```

---

### Task 4: 버스 상세 화면에서 켜짐 스위치를 없앤다

**Files:**
- Modify: `lib/features/settings/presentation/widgets/bus_settings_tiles.dart`
- Modify: `lib/features/settings/presentation/screens/bus_settings_screen.dart`
- Modify: `lib/core/constants/strings/bus_strings.dart` (`section`·`showTitle`·`showSubtitleOn`·`showSubtitleOff` 삭제)
- Modify: `test/tools/visual_check.dart:833`
- Test: `test/features/bus/bus_settings_tiles_test.dart`, `test/features/settings/bus_settings_screen_test.dart`

**Interfaces:**
- Consumes: `ModulesScreen.switchKey(id)`(Task 3, `Switch` 위젯), `BusStrings.moduleName`(기존)
- Produces: `BusSettingsTiles`에서 `switchKey` 상수가 사라진다. 상세 화면 제목은 `BusStrings.moduleName`(`출퇴근 버스`).

- [ ] **Step 1: 테스트를 다시 겨눈다**

`test/features/bus/bus_settings_tiles_test.dart` 전체를 아래로 바꾼다(선언 8 유지 — testWidgets 4 + group 1 + 그 안 2 + 마지막 1).

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/core/modules/app_module.dart';
import 'package:planroutine/core/theme/app_theme.dart';
import 'package:planroutine/features/bus/presentation/providers/bus_providers.dart';
import 'package:planroutine/features/settings/presentation/screens/modules_screen.dart';
import 'package:planroutine/features/settings/presentation/widgets/bus_settings_tiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(home: Scaffold(body: BusSettingsTiles())),
    ),
  );
  await tester.pumpAndSettle();
}

/// 팔레트와 전역 `switchTheme`을 실제로 적용한 채 **기능 관리**를 띄운다 — 색 검증 전용.
///
/// 버스를 켜는 스위치는 이제 기능 관리 행에 하나뿐이다. 그 스위치가 이 기능 전체를
/// 켜는 유일한 관문이라 색 가드(I12)도 그리로 옮긴다.
Future<void> _pumpModulesThemed(
  WidgetTester tester,
  Brightness brightness,
) async {
  AppColors.applyBrightness(brightness);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.of(brightness),
        home: const ModulesScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('상세에는 켜짐 스위치가 없고 다섯 줄이 처음부터 보인다', (tester) async {
    // 상세 화면은 기능이 켜져 있을 때만 들어온다(기능 관리 행의 ›). 그래서 여기서
    // 다시 켜고 끌 이유가 없고, 줄을 감출 이유도 없다.
    await _pump(tester);

    expect(find.byType(Switch), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.byKey(BusSettingsTiles.departureKey), findsOneWidget);
    expect(find.byKey(BusSettingsTiles.arrivalKey), findsOneWidget);
    expect(find.byKey(BusSettingsTiles.styleKey), findsOneWidget);
    expect(find.byKey(BusSettingsTiles.rangeToWorkKey), findsOneWidget);
    // 다섯째 줄도 검사한다 — 빠뜨리면 _rangeTile이 조건부로 새도 통과한다.
    expect(find.byKey(BusSettingsTiles.rangeToHomeKey), findsOneWidget);
  });

  testWidgets('켜짐 안내 문구가 없다 — 켜고 끄기는 기능 관리가 맡는다', (tester) async {
    await _pump(tester);

    expect(find.text('꺼져 있어 오늘 탭이 지금과 같습니다'), findsNothing);
    expect(find.text('지정한 시간대에만 펼쳐집니다'), findsNothing);
  });

  testWidgets('시간대 기본값이 라벨로 보인다', (tester) async {
    await _pump(tester);

    expect(find.text('07:00 – 08:30'), findsOneWidget);
    expect(find.text('16:00 – 18:00'), findsOneWidget);
  });

  testWidgets('슬롯이 비면 선택 안내가 보인다', (tester) async {
    await _pump(tester);
    expect(find.text('정류장 선택'), findsNWidgets(2));
  });

  group('버스 켜기 스위치(기능 관리) — 전역 switchTheme을 따른다 (I12)', () {
    // 팔레트는 전역이다 — 라이트로 바꾼 채 끝내면 뒤따르는 테스트가 오염된다.
    tearDown(() => AppColors.applyBrightness(Brightness.dark));

    for (final brightness in Brightness.values) {
      testWidgets('$brightness 에서 ON 썸이 트랙과 다른 색이다', (tester) async {
        await _pumpModulesThemed(tester, brightness);
        final finder = find.byKey(ModulesScreen.switchKey(ModuleIds.bus));
        await tester.tap(finder);
        await tester.pumpAndSettle();

        final sw = tester.widget<Switch>(finder);
        final theme = Theme.of(tester.element(finder));
        const selected = {WidgetState.selected};

        // Flutter의 해상 순서를 그대로 재현한다: 위젯의 `activeThumbColor`가
        // `switchTheme.thumbColor`를 밀어낸다(`switch.dart`의 `_widgetThumbColor`).
        final thumb =
            sw.activeThumbColor ??
            theme.switchTheme.thumbColor?.resolve(selected);
        final track =
            sw.activeTrackColor ??
            theme.switchTheme.trackColor?.resolve(selected);

        expect(thumb, isNotNull);
        expect(track, isNotNull);
        expect(
          thumb,
          isNot(track),
          reason:
              '썸과 트랙이 같은 색이면 ON이 썸 없는 단색 알약이 된다 — '
              'M3 스위치는 selected 그림자·외곽선이 없어 형태 단서도 없다',
        );
      });
    }

    testWidgets('켜면 실제로 켜진 상태로 그려진다', (tester) async {
      // 위 색 단정이 OFF 상태를 보고 통과하지 않도록 값 자체를 못박는다.
      await _pumpModulesThemed(tester, Brightness.dark);
      final finder = find.byKey(ModulesScreen.switchKey(ModuleIds.bus));
      await tester.tap(finder);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(finder).value, isTrue);
    });
  });

  testWidgets('카드 모양 기본은 간단히이고 눌러 바꿀 수 있다', (tester) async {
    await _pump(tester);

    expect(find.text('간단히'), findsOneWidget);

    await tester.tap(find.text('시간 축'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(BusSettingsTiles)),
    );
    expect(
      container.read(busSettingsProvider).requireValue.style.label,
      '시간 축',
    );
  });
}
```

`test/features/settings/bus_settings_screen_test.dart`의 테스트 둘을 바꾼다(선언 3 유지):

```dart
  testWidgets('화면이 설정 타일을 담고 켜짐 스위치는 없다', (tester) async {
    await pump(tester);

    expect(find.byType(BusSettingsTiles), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
  });
```

```dart
  testWidgets('제목이 기능 이름(출퇴근 버스)이다 — 기능 관리 행과 같은 이름', (tester) async {
    await pump(tester);

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text(BusStrings.moduleName),
      ),
      findsOneWidget,
    );
  });
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/bus/bus_settings_tiles_test.dart test/features/settings/bus_settings_screen_test.dart`
Expected: FAIL — 상세에 `SwitchListTile`이 남아 있고 줄이 감춰져 있다, 제목이 `버스 도착`이다

- [ ] **Step 3: 구현**

`bus_settings_tiles.dart`:
- `static const switchKey = Key('bus_show_switch');` 줄을 지운다.
- `build`에서 `installed` 변수와 그 위 주석 두 줄, `SwitchListTile(…)` 블록과 그 위 썸 색 주석 블록을 지우고, `if (installed) ...[` 의 감싸기를 풀어 다섯 줄을 `Column`의 children에 바로 둔다.
- 로딩 주석의 마지막 문장(`등록부가 로딩 중이면 …`)을 지운다.
- `app_module.dart`·`installed_modules_provider.dart` import가 더 쓰이지 않으면 지운다(analyze가 알려준다).
- 클래스 주석을 아래로 바꾼다:

```dart
/// `기능 관리 › 출퇴근 버스` 상세 화면의 본문 — 정류장·카드 모양·시간대.
///
/// **켜짐 스위치가 없다**(2026-10-03 설계). 이 화면은 버스가 켜져 있을 때만
/// 기능 관리 행의 `›`로 들어오므로, 켜고 끄는 곳은 그 행의 스위치 하나다.
```

`bus_settings_screen.dart`:
- AppBar 제목 `BusStrings.section` → `BusStrings.moduleName`.
- 클래스 주석 첫 줄 `` `설정 › 버스 도착` 상세 화면. `` → `` `기능 관리 › 출퇴근 버스` 상세 화면. 버스가 켜져 있을 때만 들어온다. ``
- `**[BusSettingsTiles]를 옮기지 않고 감싸기만 한다** — 그 위젯의 테스트 9건이 그대로 남는다.` → `**[BusSettingsTiles]를 옮기지 않고 감싸기만 한다** — 그 위젯의 테스트가 그대로 남는다.`

`bus_strings.dart`: `section`·`showTitle`·`showSubtitleOn`·`showSubtitleOff` 네 줄을 지운다. 블록 제목 `// ── 설정 섹션 ──…`은 `// ── 상세 화면 ──…`으로 바꾼다.

`test/tools/visual_check.dart:833`: `title: BusStrings.section,` → `title: BusStrings.moduleName,` (이 파일은 `flutter test`가 자동 스캔하지 않아 **analyze로만** 걸린다).

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/features/bus/ test/features/settings/ test/core/ && flutter analyze`
Expected: PASS, `No issues found!`

Run: `grep -rn "BusStrings.section\b\|showSubtitleO\|BusStrings.showTitle\|BusSettingsTiles.switchKey\|summaryOff" lib test integration_test`
Expected: 결과 없음

- [ ] **Step 5: 커밋**

```bash
git add lib/features/settings lib/core/constants/strings/bus_strings.dart test/features test/tools/visual_check.dart
git commit -m "refactor(bus): 상세 화면의 켜짐 스위치를 없앤다 — 켜고 끄기는 기능 관리 행 하나"
```

---

### Task 5: 전체 검증, 런타임 확인, 문서

**Files:**
- Modify: `CLAUDE.md` (`### 기능 모듈 (등록부)` 절, 설정 탭 구조 절, 테스트 수)
- Modify: `docs/superpowers/specs/2026-10-02-feature-modules-design.md` (끝에 한 줄)
- Modify: 옵시디언 `스펙/2026-10-02 기능 모듈 — 고정 탭 + 선택 기능.md` (같은 한 줄)

- [ ] **Step 1: 전체 테스트와 정적 검사**

Run: `flutter analyze && flutter test`
Expected: `No issues found!`, 전체 통과. 건수를 기록한다(직전 1212 + 이번 추가분).

- [ ] **Step 2: 런타임 확인 (사람이 볼 수 있게)**

1. `flutter build ios --simulator --debug --dart-define-from-file=<TAGO 키 JSON>`로 **일반 앱**을 빌드한다(integration_test를 돌린 직후의 `Runner.app`은 테스트 빌드라 흰 화면만 뜬다).
2. iPhone 17 / iOS 27.0(`832373BE-F5D2-4FDE-BCF7-65A9D8CD6592`)에 설치·실행하고 **DeviceHub**(`/Applications/Xcode.app/Contents/Applications/DeviceHub.app`)를 연다.
3. 확인: 설정 탭에 `버스 도착` 행이 없다 → `기능 관리`에서 버스를 켜면 `›`와 `정류장을 등록해 주세요`가 생긴다 → 행을 눌러 상세로 들어가면 스위치가 없고 제목이 `출퇴근 버스`다 → 정류장을 등록하고 돌아오면 부제가 `정류장 1곳`이다 → 끄면 `›`가 사라진다. 라이트·다크 둘 다.
4. 사용자에게 DeviceHub에서 직접 확인을 부탁하고 결과를 기록한다. 끝나면 `xcrun simctl shutdown all`.

- [ ] **Step 3: 문서**

CLAUDE.md:
- `### 기능 모듈 (등록부)`의 `**버스 상세 화면의 스위치는 남겼다**` bullet과 `⚠️ **설정 탭의 버스 도착 행은 꺼져 있어도 보인다**(예외)` bullet을 지우고, 그 자리에 아래를 둔다:

```markdown
- **선택 기능의 설정은 `기능 관리` 안에서만 연다**(2026-10-03, 사용자 신고로 뒤집음 — 설계는
  `docs/superpowers/specs/2026-10-03-module-settings-design.md`). 설정 탭에는 앱 공통 설정과
  고정 탭의 설정만 있고, 켜진 기능의 행에서 `›`로 상세(`settingsRoute`)에 들어간다. 켜고 끄는
  스위치는 그 행에 하나뿐이고 상세 화면에는 없다. 켜진 행의 부제는 기능이 그리는
  `settingsSummary`다(버스: `BusModuleSummary`). 가드: `settings_tab_module_rows_test.dart`
  (설정 탭이 기능 상세로 직접 가거나 요약 위젯을 그리면 실패) · `module_catalog_test.dart`
  (상세 경로가 라우터에 있다).
  - 예전에는 버스 상세에도 스위치가 있었고, 그래서 설정 탭의 `버스 도착` 행을 꺼져도 남겼다
    ("상세에서 끄고 나가면 행이 사라져 당황한다"). 스위치를 없애자 그 근거도 사라졌다.
  - 탭형 기능은 자기 탭에 같은 상세로 가는 ⚙ 지름길 하나를 둘 수 있다. 알림처럼 여러 기능에
    걸치는 설정은 마스터만 설정 탭에 둔다. `전체 데이터 초기화`는 기능의 데이터를 지우고
    설정은 남긴다 — 셋 다 스펙의 규칙 6~8이고, 처음 쓰는 기능과 함께 구현한다.
```

- `### 기능 모듈 (등록부)`의 `기능 관리 화면의 기능 목록은 …` bullet 끝에 `켜진 행은 스위치 + ›이고, 행 탭 = 상세 / 스위치 탭 = 켜고 끄기로 갈린다(\`SwitchListTile\`을 쓰지 않는 이유).`를 붙인다.
- 설정 탭 구조 절: 섹션 목록에서 `버스 도착 ·`을 빼고 `**섹션 11개**(… 실효 10~11)`를 `**섹션 10개**(… 실효 9~10)`로, `SettingsSection(`을 세면 `10개만` → `9개만`으로 고친다. 실제 수는 `grep -c "SettingsSection(" lib/features/settings/presentation/screens/settings_screen.dart`로 세어 확인한다(+1이 `CalendarIntegrationSection`).
- 설정 탭 구조 절의 "깊은 설정은 화면 밖으로 뺀다" 아래 버스 bullet 중 `설정 탭에 남는 요약은 순수 함수 \`buildBusSettingsSummary\`가 만든다 (\`꺼짐\` / \`켜짐 · 정류장 없음\` / \`켜짐 · N곳\`)` 문장을 `기능 관리의 켜진 버스 행 부제는 순수 함수 \`buildBusSettingsSummary\`가 만든다(\`정류장을 등록해 주세요\` / \`정류장 N곳\`)`로 고치고, 같은 bullet의 `**켜짐 여부를 정류장 수보다 먼저 본다**…` 문장을 지운다(켜진 행에만 쓰이므로 켜짐을 보지 않는다).
- 기술 스택 테스트 칸과 README의 테스트 수를 Step 1 실측값으로 고친다.

`2026-10-02-feature-modules-design.md` 맨 끝과 옵시디언 사본 끝에 한 줄:

```markdown
> 2026-10-03: 위 이탈 ①·②는 `2026-10-03-module-settings-design.md`로 뒤집혔다 — 버스 상세의 스위치를 없애고, 설정 탭에서 버스 행을 뺐다.
```

Run: `flutter test test/deploy` (CLAUDE.md를 훑는 레인 문서 가드)
Expected: PASS

- [ ] **Step 4: 커밋**

```bash
git add CLAUDE.md README.md docs/superpowers/specs/2026-10-02-feature-modules-design.md
git commit -m "docs: 기능별 설정은 기능 관리 안 — CLAUDE.md·스펙 반영"
```

- [ ] **Step 5: 작업 로그·배포 제안**

`document-release` 스킬로 옵시디언 작업 로그를 남길지, TestFlight에 올릴지 사용자에게 묻는다.
