# 기능 모듈 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 탭 목록을 상수에서 기능 등록부로 바꾸고, 사용자가 `기능 관리` 화면에서 선택 기능을 스위치로 켜고 끄며 탭 순서를 바꾸게 한다. 출퇴근 버스 카드를 첫 선택 기능으로 이전한다.

**Architecture:** `lib/core/modules/`에 순수 도메인(`AppModule`·`resolveModules`·이전 함수)과 등록부(`moduleCatalog`), 설치 상태 provider(`installedModulesProvider`, shared_preferences `installed_modules_v1`)를 둔다. `MainShell`은 탭 목록을 인자로 받고, 오늘 탭은 `InstalledTodayCards`가 설치된 카드형 기능을 그린다. 버스의 켜짐 여부는 `BusSettings.enabled`에서 등록부로 옮긴다.

**Tech Stack:** Flutter 3.44.8 / Dart 3.12.2, Riverpod(AsyncNotifier), GoRouter(ShellRoute), shared_preferences, flutter_test

**Spec:** `docs/superpowers/specs/2026-10-02-feature-modules-design.md`

## 실행 전 필수 조건

- ⚠️ **Xcode 라이선스 동의가 필요하다**(`sudo xcodebuild -license`). 동의 전에는 `git`이 xcrun 셰임에서 멈추고, `flutter test`는 `Building native assets failed`로 실패한다(2026-10-02 실측). `dart analyze`만 `PATH=/Library/Developer/CommandLineTools/usr/bin:$PATH`로 우회된다. **동의 전에는 Task 1을 시작하지 않는다** — TDD 사이클이 성립하지 않는다.

## Spec과 다른 점 (승인 필요)

코드를 읽고 나서 스펙보다 나은 쪽을 골랐다. 사용자가 계획을 승인하면 Task 8에서 스펙도 함께 고친다.

1. **버스 상세 설정의 마스터 스위치를 없애지 않고, 등록부에 다시 묶는다.** 스펙은 스위치를 없애라고 했지만, 남기더라도 그 스위치가 `installedModulesProvider`를 읽고 쓰면 진실 공급원은 여전히 하나다. 대신 `bus_settings_tiles_test.dart`의 8건이 거의 그대로 살아남고, 이미 버스를 쓰는 사용자가 익숙한 자리에서 끌 수 있다.
2. **설정 탭의 `버스 도착` 행은 꺼져 있어도 보인다**(지금과 같다). 스위치를 상세 화면에 남기면, 거기서 끄고 뒤로 가는 순간 행이 사라져 "어디 갔지?"가 된다 — 스위치 방식을 고른 이유(자리 고정)와 정면으로 어긋난다. 요약의 `꺼짐`도 그대로 쓰인다. **"기능별 설정은 켜져 있을 때만 보인다"는 규칙은 앞으로 만들 기능부터 적용한다.**
3. **빠진 고정 탭은 "기본 순서 자리"가 아니라 카탈로그 순서로 설정 앞에 붙인다.** 고정 탭이 저장값에서 빠지는 경우는 첫 실행(저장값 없음)과 손상뿐이다. 첫 실행이면 결과가 기본 순서와 같고, 손상이면 어느 자리든 정답이 없다. 규칙을 단순하게 둔다.
4. **버스 카드 호스트(`BusCardHost`) 안의 켜짐 검사는 없앤다. 설치 여부는 카드를 화면에 올릴지에서만 본다**(`InstalledTodayCards`). 호스트 안에서 비동기 provider를 하나 더 기다리면 `listenManual` 촉발 순서(호스트 `initState`의 긴 주석)에 경합이 생긴다. "꺼져 있고 정류장이 남아도 요청 0"을 지키던 가드 테스트 둘은 `InstalledTodayCards`를 띄우는 형태로 같은 파일 안에서 다시 겨눈다.

## Global Constraints

- 탭 상한 `kMaxTabs = 6`. 카드형 기능은 상한에 포함하지 않는다.
- 고정 탭: 오늘·캘린더·입력·설정(`fixed: true`). 숨길 수 없고 순서는 자유. **설정은 항상 맨 끝.**
- 저장 키 `installed_modules_v1`(id 목록 JSON). 버스 설정 키 `bus_settings_v1`는 그대로.
- 기능 id는 저장값이다. **한번 배포한 id는 바꾸거나 지우지 않는다.** id는 `*Strings`에 두지 않는다.
- 끄더라도 기능의 데이터(버스 정류장·시간대)는 지우지 않는다. 그래서 확인 다이얼로그를 띄우지 않는다.
- Riverpod만 쓴다. 문자열은 `*Strings`, 색은 `AppColors`, 크기는 `AppSizes`. 한글 UI·한글 주석.
- `shared/widgets/`는 `features/`를 직접 import하지 않는다(`core/`는 된다).
- **기존 테스트를 지우지 않는다.** `enabled`에 기대던 테스트는 같은 의도를 새 진실 공급원으로 다시 겨눈다. 파일별 `test(`/`testWidgets(`/`group(` 선언 수가 줄면 `protect-tests.sh` 훅이 막는다.
- 스위치에 `activeThumbColor`를 주지 않는다(전역 `switchTheme` 색 가드).
- `ListTile` 위에 색칠된 `Container`를 끼우지 않는다.
- 아이폰 단축어(App Intents) 코드와 가드는 건드리지 않는다(보류 중, 스펙 "건드리지 않는 것").

## Review Focus

1. **버스를 켜 둔 기존 사용자의 업그레이드** — 이전 후에도 오늘 탭에 버스 카드가 그대로 보여야 한다. → Task 2 이전 테스트 + Task 8 시뮬레이터 업그레이드 실측.
2. **손상된 `installed_modules_v1`**(JSON이 아님, 리스트가 아님, 문자열이 아닌 원소) — 크래시 없이 기본 4탭으로 떠야 한다. → Task 2 `손상된 저장값` 테스트.
3. **provider 로딩 중의 첫 프레임** — 탭바가 비거나 예외가 나면 안 되고 기본 4탭이 보여야 한다. 오늘 탭 카드 자리는 비어 있어야 한다. → Task 3 `로딩 중에는 기본 4탭` 테스트, Task 4 `로딩 중에는 카드가 없다` 테스트.
4. **탭이 가득 찬 상태에서 켜기** — UI가 막는 것과 별개로 notifier도 거부해야 한다(다른 호출부가 생겨도 7번째 탭이 저장되지 않게). → Task 2 `setEnabled는 상한을 넘기지 않는다` 테스트.
5. **두 스위치가 같은 진실을 보는지** — 버스 상세 설정에서 끈 것이 `기능 관리` 화면에도 꺼져 보여야 한다. → Task 6 `버스 상세 스위치와 기능 관리 스위치가 같은 값을 본다` 테스트.

---

## 파일 구조

| 파일 | 역할 | 작업 |
|---|---|---|
| `lib/core/modules/app_module.dart` | `ModuleIds`·`ModulePlacement`·`ModuleTab`·`AppModule`·`ResolvedModules` | Create |
| `lib/core/modules/module_rules.dart` | `kMaxTabs`·`resolveModules`·`decodeModuleIds`·`migrateLegacyModuleIds` (순수) | Create |
| `lib/core/modules/module_catalog.dart` | 고정 탭 4개 `ModuleTab` 상수 + `moduleCatalog` | Create |
| `lib/core/modules/installed_modules_provider.dart` | `moduleCatalogProvider`·`installedModulesProvider`·`moduleInstalledProvider` | Create |
| `lib/core/modules/installed_today_cards.dart` | 설치된 카드형 기능을 그리는 위젯 | Create |
| `lib/core/modules/module_shell.dart` | 등록부 → `MainShell` 탭 목록 배선 | Create |
| `lib/shared/widgets/main_shell.dart` | 탭 목록을 인자로 받음, 주인 탭 폴백 | Modify |
| `lib/core/router/app_router.dart` | `AppRoutes.modules`, ShellRoute builder가 탭 목록 전달, `/modules` 라우트 | Modify |
| `lib/features/today/presentation/widgets/today_body.dart` | `busCard` → `cards` | Modify |
| `lib/features/today/presentation/screens/today_screen.dart` | `InstalledTodayCards` 전달 | Modify |
| `lib/features/bus/domain/bus_settings.dart` | `enabled` 제거 | Modify |
| `lib/features/bus/domain/bus_settings_summary.dart` | `installed` 인자 | Modify |
| `lib/features/bus/presentation/providers/bus_providers.dart` | `setEnabled` 제거, 키 공개 | Modify |
| `lib/features/bus/presentation/widgets/bus_card_host.dart` | `enabled` 검사 3곳 제거 | Modify |
| `lib/features/settings/presentation/widgets/bus_settings_tiles.dart` | 스위치를 등록부에 묶음 | Modify |
| `lib/features/settings/presentation/widgets/bus_summary_list_tile.dart` | 설치 여부로 요약 | Modify |
| `lib/features/settings/presentation/screens/modules_screen.dart` | `기능 관리` 화면 | Create |
| `lib/features/settings/presentation/widgets/modules_list_tile.dart` | 설정 탭 진입 행 | Create |
| `lib/features/settings/presentation/screens/settings_screen.dart` | 진입 행 추가 | Modify |
| `lib/core/constants/strings/settings_strings.dart` · `bus_strings.dart` | 문자열 | Modify |
| `test/helpers/module_prefs.dart` | 테스트용 prefs 조립 헬퍼 | Create |

---

### Task 1: 도메인과 정리 규칙

**Files:**
- Create: `lib/core/modules/app_module.dart`
- Create: `lib/core/modules/module_rules.dart`
- Test: `test/core/modules/resolve_modules_test.dart`

**Interfaces:**
- Produces:
  - `abstract final class ModuleIds { today, calendar, schedule, settings, bus }` (String 상수)
  - `enum ModulePlacement { tab, todayCard }`
  - `class ModuleTab { route, icon, activeIcon, label }` (const)
  - `class AppModule { id, name, description, icon, placement, fixed, tab, card }` (const)
  - `class ResolvedModules { List<AppModule> tabs; List<AppModule> cards; List<String> get ids; }`
  - `const kMaxTabs = 6;`
  - `ResolvedModules resolveModules(List<AppModule> catalog, List<String>? savedIds)`
  - `List<String>? decodeModuleIds(String? raw)`
  - `List<String> migrateLegacyModuleIds(String? busSettingsRaw)`

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
// test/core/modules/resolve_modules_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/modules/app_module.dart';
import 'package:planroutine/core/modules/module_rules.dart';

ModuleTab _tab(String route) => ModuleTab(
  route: route,
  icon: Icons.circle_outlined,
  activeIcon: Icons.circle,
  label: route,
);

AppModule _fixed(String id) => AppModule(
  id: id,
  name: id,
  icon: Icons.circle,
  placement: ModulePlacement.tab,
  fixed: true,
  tab: _tab('/$id'),
);

AppModule _optionalTab(String id) => AppModule(
  id: id,
  name: id,
  icon: Icons.circle,
  placement: ModulePlacement.tab,
  tab: _tab('/$id'),
);

AppModule _card(String id) => AppModule(
  id: id,
  name: id,
  icon: Icons.circle,
  placement: ModulePlacement.todayCard,
  card: const SizedBox(),
);

final _catalog = [
  _fixed(ModuleIds.today),
  _fixed(ModuleIds.calendar),
  _fixed(ModuleIds.schedule),
  _fixed(ModuleIds.settings),
  _card(ModuleIds.bus),
  _optionalTab('t1'),
  _optionalTab('t2'),
  _optionalTab('t3'),
];

List<String> _tabIds(ResolvedModules r) => r.tabs.map((m) => m.id).toList();

void main() {
  group('resolveModules', () {
    test('저장값이 없으면 고정 4탭만, 카탈로그 순서로', () {
      final r = resolveModules(_catalog, null);
      expect(_tabIds(r), ['today', 'calendar', 'schedule', 'settings']);
      expect(r.cards, isEmpty);
    });

    test('저장 순서가 곧 탭 순서다', () {
      final r = resolveModules(_catalog, [
        'calendar',
        'today',
        'schedule',
        'settings',
      ]);
      expect(_tabIds(r), ['calendar', 'today', 'schedule', 'settings']);
    });

    test('빠진 고정 탭은 카탈로그 순서로 설정 앞에 붙는다', () {
      final r = resolveModules(_catalog, ['schedule']);
      expect(_tabIds(r), ['schedule', 'today', 'calendar', 'settings']);
    });

    test('설정은 저장 위치와 무관하게 맨 끝이다', () {
      final r = resolveModules(_catalog, [
        'settings',
        'today',
        'calendar',
        'schedule',
      ]);
      expect(_tabIds(r).last, 'settings');
    });

    test('등록부에 없는 id는 조용히 버린다', () {
      final r = resolveModules(_catalog, ['gone', 'today', 'bus']);
      expect(r.ids, isNot(contains('gone')));
      expect(r.cards.map((m) => m.id), ['bus']);
    });

    test('중복 id는 첫 등장만 남는다', () {
      final r = resolveModules(_catalog, ['t1', 'today', 't1']);
      expect(_tabIds(r).where((id) => id == 't1'), hasLength(1));
      expect(_tabIds(r).first, 't1');
    });

    test('탭이 6개를 넘으면 뒤쪽 선택 탭부터 잘린다 — 고정과 설정은 남는다', () {
      final r = resolveModules(_catalog, [
        'today',
        'calendar',
        'schedule',
        't1',
        't2',
        't3',
        'settings',
      ]);
      expect(r.tabs, hasLength(kMaxTabs));
      expect(_tabIds(r), [
        'today',
        'calendar',
        'schedule',
        't1',
        't2',
        'settings',
      ]);
    });

    test('카드형은 탭 상한에 포함되지 않는다', () {
      final r = resolveModules(_catalog, [
        'today',
        'calendar',
        'schedule',
        't1',
        't2',
        'settings',
        'bus',
      ]);
      expect(r.tabs, hasLength(6));
      expect(r.cards.map((m) => m.id), ['bus']);
    });

    test('ids는 탭 다음 카드 순서다', () {
      final r = resolveModules(_catalog, ['bus', 'today']);
      expect(r.ids, ['today', 'calendar', 'schedule', 'settings', 'bus']);
    });
  });

  group('decodeModuleIds', () {
    test('null이면 null', () => expect(decodeModuleIds(null), isNull));

    test('정상 목록을 읽는다', () {
      expect(decodeModuleIds('["today","bus"]'), ['today', 'bus']);
    });

    test('손상된 저장값이면 null — 기본값으로 떨어진다', () {
      expect(decodeModuleIds('not json'), isNull);
      expect(decodeModuleIds('{"a":1}'), isNull);
    });

    test('문자열이 아닌 원소는 버린다', () {
      expect(decodeModuleIds('["today",3,null,"bus"]'), ['today', 'bus']);
    });
  });

  group('migrateLegacyModuleIds — bus_settings_v1의 enabled 이전', () {
    test('버스를 켜 둔 기존 사용자는 버스가 설치된다', () {
      expect(migrateLegacyModuleIds('{"enabled":true}'), [ModuleIds.bus]);
    });

    test('꺼 둔 기존 사용자는 아무것도 설치되지 않는다', () {
      expect(migrateLegacyModuleIds('{"enabled":false}'), isEmpty);
    });

    test('신규 사용자(키 없음)는 아무것도 설치되지 않는다', () {
      expect(migrateLegacyModuleIds(null), isEmpty);
    });

    test('bus_settings_v1이 깨져 있으면 설치하지 않는다', () {
      expect(migrateLegacyModuleIds('{{{'), isEmpty);
      expect(migrateLegacyModuleIds('[1,2]'), isEmpty);
    });
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/core/modules/resolve_modules_test.dart`
Expected: FAIL — `app_module.dart`·`module_rules.dart`가 없어 컴파일 오류

- [ ] **Step 3: 구현**

```dart
// lib/core/modules/app_module.dart
import 'package:flutter/widgets.dart';

/// 기능 id — **저장값이다.** 한번 배포하면 바꾸거나 지우지 않는다.
///
/// `*Strings`에 두지 않는 이유는 Android 알림 채널 id와 같다: UI 문자열이
/// 아니라 사용자 기기에 저장되는 키라, 바꾸면 그 기능을 켜 둔 사용자의 설정이
/// 조용히 꺼진다. `module_catalog_test.dart`가 배포한 id 목록을 지킨다.
abstract final class ModuleIds {
  static const today = 'today';
  static const calendar = 'calendar';
  static const schedule = 'schedule';
  static const settings = 'settings';
  static const bus = 'bus';
}

/// 기능이 화면에 들어오는 자리. 한 기능은 하나의 자리만 갖는다.
enum ModulePlacement { tab, todayCard }

/// 탭바 한 칸. `MainShell`이 그린다.
class ModuleTab {
  const ModuleTab({
    required this.route,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final String route;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// 등록부의 한 항목. 새 기능을 만들면 `moduleCatalog`에 이것 하나를 더한다.
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
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final ModulePlacement placement;

  /// 숨길 수 없는 기능. 순서는 바꿀 수 있다.
  final bool fixed;

  /// [placement]가 tab일 때만 있다.
  final ModuleTab? tab;

  /// [placement]가 todayCard일 때만 있다. 오늘 탭 맨 위에 놓인다.
  final Widget? card;
}

/// [resolveModules]가 정리한 결과. 화면은 저장값이 아니라 이것만 본다.
class ResolvedModules {
  const ResolvedModules({required this.tabs, required this.cards});

  /// 탭 순서대로. 설정이 항상 맨 끝이다.
  final List<AppModule> tabs;

  /// 오늘 탭 카드. 켠 순서대로.
  final List<AppModule> cards;

  /// 저장할 id 목록 — 탭 다음 카드.
  List<String> get ids => [
    for (final m in tabs) m.id,
    for (final m in cards) m.id,
  ];
}
```

```dart
// lib/core/modules/module_rules.dart
import 'dart:convert';

import 'app_module.dart';

/// 탭바에 들어가는 최대 칸 수. 320pt에서 6칸이면 한 칸이 53pt다.
const kMaxTabs = 6;

/// 저장값을 화면이 쓸 수 있는 형태로 정리한다. **저장값을 그대로 믿지 않는다.**
///
/// 규칙(스펙 "정리 규칙"):
/// 1. 고정 탭은 저장값에 없어도 포함한다 — 카탈로그 순서로 설정 앞에 붙는다.
/// 2. 설정은 항상 맨 끝이다.
/// 3. 등록부에 없는 id(사라진 기능)는 버린다.
/// 4. 중복 id는 첫 등장만 남긴다.
/// 5. 탭이 [kMaxTabs]를 넘으면 뒤쪽 선택 탭부터 잘라 낸다.
/// 6. 저장값이 null이면 고정 탭만 남는다.
ResolvedModules resolveModules(List<AppModule> catalog, List<String>? savedIds) {
  final byId = {for (final m in catalog) m.id: m};
  final seen = <String>{};
  final tabs = <AppModule>[];
  final cards = <AppModule>[];

  for (final id in savedIds ?? const <String>[]) {
    final module = byId[id];
    if (module == null || !seen.add(id)) continue;
    (module.placement == ModulePlacement.tab ? tabs : cards).add(module);
  }
  for (final module in catalog) {
    if (module.fixed && seen.add(module.id)) tabs.add(module);
  }

  final settings = tabs.firstWhere((m) => m.id == ModuleIds.settings);
  tabs.remove(settings);
  while (tabs.length + 1 > kMaxTabs) {
    final last = tabs.lastIndexWhere((m) => !m.fixed);
    if (last < 0) break;
    tabs.removeAt(last);
  }
  tabs.add(settings);

  return ResolvedModules(
    tabs: List.unmodifiable(tabs),
    cards: List.unmodifiable(cards),
  );
}

/// `installed_modules_v1`을 읽는다. 손상됐으면 null — 기본값으로 떨어진다.
List<String>? decodeModuleIds(String? raw) {
  if (raw == null) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return null;
    return decoded.whereType<String>().toList();
  } catch (_) {
    return null;
  }
}

/// 등록부 이전 전의 버스 켜짐(`bus_settings_v1`의 `enabled`)을 설치 목록으로 옮긴다.
///
/// `installed_modules_v1`이 없을 때 **한 번만** 부른다. 이 함수가 `enabled`를
/// 읽는 유일한 곳이다 — `BusSettings`에서는 그 필드가 사라졌다.
List<String> migrateLegacyModuleIds(String? busSettingsRaw) {
  if (busSettingsRaw == null) return const [];
  try {
    final decoded = jsonDecode(busSettingsRaw);
    if (decoded is Map && decoded['enabled'] == true) {
      return const [ModuleIds.bus];
    }
  } catch (_) {
    // 깨진 값이면 설치하지 않는다
  }
  return const [];
}
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/core/modules/resolve_modules_test.dart`
Expected: PASS (17건)

- [ ] **Step 5: 커밋**

```bash
git add lib/core/modules/app_module.dart lib/core/modules/module_rules.dart test/core/modules/resolve_modules_test.dart
git commit -m "feat(modules): 기능 등록부 도메인과 정리 규칙"
```

---

### Task 2: 등록부와 설치 상태 provider

**Files:**
- Create: `lib/core/modules/module_catalog.dart`
- Create: `lib/core/modules/installed_modules_provider.dart`
- Create: `test/helpers/module_prefs.dart`
- Modify: `lib/features/bus/presentation/providers/bus_providers.dart:13` (`_prefsKey` → 공개 `busSettingsPrefsKey`)
- Modify: `lib/core/constants/strings/bus_strings.dart` (`moduleName`·`moduleDescription`)
- Test: `test/core/modules/installed_modules_provider_test.dart`

**Interfaces:**
- Consumes: Task 1 전부
- Produces:
  - `const todayTab, calendarTab, scheduleTab, settingsTab` (`ModuleTab`), `const defaultTabs = [todayTab, calendarTab, scheduleTab, settingsTab]`
  - `const List<AppModule> moduleCatalog`
  - `const installedModulesPrefsKey = 'installed_modules_v1'`
  - `final moduleCatalogProvider = Provider<List<AppModule>>`
  - `final installedModulesProvider = AsyncNotifierProvider<InstalledModulesNotifier, ResolvedModules>`
  - `InstalledModulesNotifier.setEnabled(String id, bool on) → Future<bool>` (거부 시 false)
  - `InstalledModulesNotifier.reorderTabs(int oldIndex, int newIndex) → Future<void>` (설정을 뺀 탭 목록 기준, `ReorderableListView.onReorder` 규약)
  - `final moduleInstalledProvider = Provider.family<bool, String>` (로딩 중 false)
  - `const busSettingsPrefsKey = 'bus_settings_v1'`
  - 테스트 헬퍼 `Map<String, Object> modulePrefs({List<String> installed = const [], BusSettings? bus})`

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
// test/helpers/module_prefs.dart
import 'dart:convert';

import 'package:planroutine/core/modules/installed_modules_provider.dart';
import 'package:planroutine/features/bus/domain/bus_settings.dart';
import 'package:planroutine/features/bus/presentation/providers/bus_providers.dart';

/// `SharedPreferences.setMockInitialValues`에 넘길 값.
///
/// [installed]는 고정 탭을 뺀 선택 기능 id만 적어도 된다 — `resolveModules`가
/// 고정 탭을 채운다. 키를 **항상** 넣어 이전 로직이 끼어들지 않게 한다.
Map<String, Object> modulePrefs({
  List<String> installed = const [],
  BusSettings? bus,
}) => {
  installedModulesPrefsKey: jsonEncode(installed),
  if (bus != null) busSettingsPrefsKey: jsonEncode(bus.toJson()),
};
```

```dart
// test/core/modules/installed_modules_provider_test.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/modules/app_module.dart';
import 'package:planroutine/core/modules/installed_modules_provider.dart';
import 'package:planroutine/core/modules/module_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 탭형 선택 기능이 아직 없으므로 테스트용 둘을 주입한다.
const _t1 = AppModule(
  id: 't1',
  name: 't1',
  icon: Icons.circle,
  placement: ModulePlacement.tab,
  tab: ModuleTab(
    route: '/t1',
    icon: Icons.circle_outlined,
    activeIcon: Icons.circle,
    label: 't1',
  ),
);
const _t2 = AppModule(
  id: 't2',
  name: 't2',
  icon: Icons.circle,
  placement: ModulePlacement.tab,
  tab: ModuleTab(
    route: '/t2',
    icon: Icons.circle_outlined,
    activeIcon: Icons.circle,
    label: 't2',
  ),
);
const _t3 = AppModule(
  id: 't3',
  name: 't3',
  icon: Icons.circle,
  placement: ModulePlacement.tab,
  tab: ModuleTab(
    route: '/t3',
    icon: Icons.circle_outlined,
    activeIcon: Icons.circle,
    label: 't3',
  ),
);

ProviderContainer _container() {
  final c = ProviderContainer(
    overrides: [
      moduleCatalogProvider.overrideWithValue([
        ...moduleCatalog,
        _t1,
        _t2,
        _t3,
      ]),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<List<String>?> _saved() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(installedModulesPrefsKey);
  return raw == null ? null : List<String>.from(jsonDecode(raw) as List);
}

void main() {
  group('이전', () {
    test('버스를 켜 둔 기존 사용자는 첫 읽기에서 버스가 설치되고 저장된다', () async {
      SharedPreferences.setMockInitialValues({
        'bus_settings_v1': '{"enabled":true}',
      });
      final r = await _container().read(installedModulesProvider.future);
      expect(r.cards.map((m) => m.id), [ModuleIds.bus]);
      expect(await _saved(), contains(ModuleIds.bus));
    });

    test('이미 이전한 사용자는 다시 이전하지 않는다 — 버스를 끈 뒤 enabled가 남아 있어도', () async {
      SharedPreferences.setMockInitialValues({
        'bus_settings_v1': '{"enabled":true}',
        installedModulesPrefsKey: '["today","calendar","schedule","settings"]',
      });
      final r = await _container().read(installedModulesProvider.future);
      expect(r.cards, isEmpty);
    });

    test('손상된 저장값이면 기본 4탭으로 뜬다', () async {
      SharedPreferences.setMockInitialValues({
        installedModulesPrefsKey: 'not json',
      });
      final r = await _container().read(installedModulesProvider.future);
      expect(r.tabs.map((m) => m.id), [
        'today',
        'calendar',
        'schedule',
        'settings',
      ]);
    });
  });

  group('setEnabled', () {
    setUp(() => SharedPreferences.setMockInitialValues({
      installedModulesPrefsKey: '[]',
    }));

    test('탭형을 켜면 설정 바로 앞에 들어간다', () async {
      final c = _container();
      await c.read(installedModulesProvider.future);
      expect(
        await c.read(installedModulesProvider.notifier).setEnabled('t1', true),
        isTrue,
      );
      final ids = c.read(installedModulesProvider).requireValue.tabs
          .map((m) => m.id);
      expect(ids, ['today', 'calendar', 'schedule', 't1', 'settings']);
      expect(await _saved(), contains('t1'));
    });

    test('끄면 빠지고 저장된다', () async {
      final c = _container();
      await c.read(installedModulesProvider.future);
      final n = c.read(installedModulesProvider.notifier);
      await n.setEnabled(ModuleIds.bus, true);
      await n.setEnabled(ModuleIds.bus, false);
      expect(await _saved(), isNot(contains(ModuleIds.bus)));
    });

    test('고정 탭은 끌 수 없다', () async {
      final c = _container();
      await c.read(installedModulesProvider.future);
      expect(
        await c
            .read(installedModulesProvider.notifier)
            .setEnabled(ModuleIds.calendar, false),
        isFalse,
      );
      expect(
        c.read(installedModulesProvider).requireValue.ids,
        contains(ModuleIds.calendar),
      );
    });

    test('setEnabled는 상한을 넘기지 않는다 — UI가 아니어도', () async {
      final c = _container();
      await c.read(installedModulesProvider.future);
      final n = c.read(installedModulesProvider.notifier);
      await n.setEnabled('t1', true);
      await n.setEnabled('t2', true); // 6칸 가득
      expect(await n.setEnabled('t3', true), isFalse);
      expect(c.read(installedModulesProvider).requireValue.tabs, hasLength(6));
    });

    test('moduleInstalledProvider가 켜짐을 따라간다', () async {
      final c = _container();
      await c.read(installedModulesProvider.future);
      expect(c.read(moduleInstalledProvider(ModuleIds.bus)), isFalse);
      await c
          .read(installedModulesProvider.notifier)
          .setEnabled(ModuleIds.bus, true);
      expect(c.read(moduleInstalledProvider(ModuleIds.bus)), isTrue);
    });
  });

  group('reorderTabs', () {
    setUp(() => SharedPreferences.setMockInitialValues({
      installedModulesPrefsKey: '[]',
    }));

    test('아래로 옮기면 onReorder 규약대로 한 칸 당겨 넣는다', () async {
      final c = _container();
      await c.read(installedModulesProvider.future);
      // 오늘(0)을 입력(2) 뒤로: ReorderableListView는 newIndex=3을 준다
      await c.read(installedModulesProvider.notifier).reorderTabs(0, 3);
      expect(
        c.read(installedModulesProvider).requireValue.tabs.map((m) => m.id),
        ['calendar', 'schedule', 'today', 'settings'],
      );
    });

    test('옮긴 순서가 저장되고 설정은 여전히 맨 끝이다', () async {
      final c = _container();
      await c.read(installedModulesProvider.future);
      await c.read(installedModulesProvider.notifier).reorderTabs(2, 0);
      final saved = await _saved();
      expect(saved?.first, 'schedule');
      expect(
        c.read(installedModulesProvider).requireValue.tabs.last.id,
        ModuleIds.settings,
      );
    });
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/core/modules/installed_modules_provider_test.dart`
Expected: FAIL — `installed_modules_provider.dart`·`module_catalog.dart` 없음

- [ ] **Step 3: 구현**

`bus_providers.dart`의 13행을 공개 상수로 바꾸고 파일 안의 `_prefsKey` 참조(3곳: `build`의 `getString`·`setString`, `_save`)를 모두 바꾼다.

```dart
/// 버스 설정 저장 키. 등록부 이전(`migrateLegacyModuleIds`)이 이 키를 읽는다.
const busSettingsPrefsKey = 'bus_settings_v1';
```

`bus_strings.dart`의 `section` 아래에 추가:

```dart
  // 기능 관리
  static const moduleName = '출퇴근 버스';
  static const moduleDescription = '오늘 탭 맨 위에 버스 도착 시간을 보여줘요';
```

```dart
// lib/core/modules/module_catalog.dart
import 'package:flutter/material.dart';

import '../../features/bus/presentation/widgets/bus_card_host.dart';
import '../constants/app_strings.dart';
import '../router/app_router.dart';
import 'app_module.dart';

const todayTab = ModuleTab(
  route: AppRoutes.today,
  icon: Icons.check_circle_outline,
  activeIcon: Icons.check_circle,
  label: AppStrings.tabToday,
);

const calendarTab = ModuleTab(
  route: AppRoutes.calendar,
  icon: Icons.calendar_month_outlined,
  activeIcon: Icons.calendar_month,
  label: AppStrings.tabCalendar,
);

const scheduleTab = ModuleTab(
  route: AppRoutes.schedule,
  // 이 탭의 주 동작은 검토가 아니라 넣기 — 체크리스트 아이콘은 어긋난다.
  icon: Icons.note_add_outlined,
  activeIcon: Icons.note_add,
  label: AppStrings.tabSchedule,
);

const settingsTab = ModuleTab(
  route: AppRoutes.settings,
  icon: Icons.settings_outlined,
  activeIcon: Icons.settings,
  label: SettingsStrings.title,
);

/// 등록부가 아직 로딩 중일 때와 `MainShell`의 기본값.
const defaultTabs = [todayTab, calendarTab, scheduleTab, settingsTab];

/// 기능 등록부. **새 기능은 여기에 한 항목만 더한다.**
///
/// 탭형 기능의 라우트는 설치 여부와 무관하게 `app_router.dart`에 항상 등록한다
/// (`module_catalog_test.dart`가 지킨다).
const moduleCatalog = <AppModule>[
  AppModule(
    id: ModuleIds.today,
    name: AppStrings.tabToday,
    icon: Icons.check_circle_outline,
    placement: ModulePlacement.tab,
    fixed: true,
    tab: todayTab,
  ),
  AppModule(
    id: ModuleIds.calendar,
    name: AppStrings.tabCalendar,
    icon: Icons.calendar_month_outlined,
    placement: ModulePlacement.tab,
    fixed: true,
    tab: calendarTab,
  ),
  AppModule(
    id: ModuleIds.schedule,
    name: AppStrings.tabSchedule,
    icon: Icons.note_add_outlined,
    placement: ModulePlacement.tab,
    fixed: true,
    tab: scheduleTab,
  ),
  AppModule(
    id: ModuleIds.settings,
    name: SettingsStrings.title,
    icon: Icons.settings_outlined,
    placement: ModulePlacement.tab,
    fixed: true,
    tab: settingsTab,
  ),
  AppModule(
    id: ModuleIds.bus,
    name: BusStrings.moduleName,
    description: BusStrings.moduleDescription,
    icon: Icons.directions_bus_outlined,
    placement: ModulePlacement.todayCard,
    card: BusCardHost(),
  ),
];
```

```dart
// lib/core/modules/installed_modules_provider.dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/bus/presentation/providers/bus_providers.dart';
import 'app_module.dart';
import 'module_catalog.dart';
import 'module_rules.dart';

const installedModulesPrefsKey = 'installed_modules_v1';

/// 등록부. 테스트가 탭형 테스트용 기능을 주입하려고 provider로 감싼다.
final moduleCatalogProvider = Provider<List<AppModule>>((ref) => moduleCatalog);

/// 설치된 기능과 탭 순서 — **켜짐 여부의 유일한 주인.**
final installedModulesProvider =
    AsyncNotifierProvider<InstalledModulesNotifier, ResolvedModules>(
      InstalledModulesNotifier.new,
    );

/// 이 기능이 켜져 있는가. 로딩 중에는 false.
final moduleInstalledProvider = Provider.family<bool, String>((ref, id) {
  final resolved = ref.watch(installedModulesProvider).valueOrNull;
  return resolved?.ids.contains(id) ?? false;
});

class InstalledModulesNotifier extends AsyncNotifier<ResolvedModules> {
  List<AppModule> get _catalog => ref.read(moduleCatalogProvider);

  @override
  Future<ResolvedModules> build() async {
    final catalog = ref.watch(moduleCatalogProvider);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(installedModulesPrefsKey);
    if (raw != null) return resolveModules(catalog, decodeModuleIds(raw));

    // **키가 없을 때 한 번만** 이전한다. 판정 기준이 "키가 있는가" 하나라 같은
    // 사용자를 두 번 이전하지 않는다. `_save`를 쓰지 않는다 — build 중에는
    // state를 대입할 수 없다(반환값이 곧 state).
    final migrated = resolveModules(
      catalog,
      migrateLegacyModuleIds(prefs.getString(busSettingsPrefsKey)),
    );
    await prefs.setString(installedModulesPrefsKey, jsonEncode(migrated.ids));
    return migrated;
  }

  /// 켜기·끄기. **거부하면 false** — 고정 탭을 끄려 하거나 탭이 가득 찼을 때.
  ///
  /// 상한을 여기서도 검사한다. 화면이 스위치를 막는 것만으로는 다른 호출부가
  /// 생겼을 때 7번째 탭이 저장된다.
  Future<bool> setEnabled(String id, bool on) async {
    final current = await future;
    final module = _catalog.where((m) => m.id == id).firstOrNull;
    if (module == null || module.fixed) return false;

    final ids = current.ids.where((x) => x != id).toList();
    if (on) {
      if (module.placement == ModulePlacement.tab) {
        if (current.tabs.length >= kMaxTabs) return false;
        ids.insert(ids.indexOf(ModuleIds.settings), id);
      } else {
        ids.add(id);
      }
    }
    await _save(resolveModules(_catalog, ids));
    return true;
  }

  /// 설정을 뺀 탭 목록에서 순서를 바꾼다. `ReorderableListView.onReorder` 규약이라
  /// 아래로 옮길 때 [newIndex]가 한 칸 크게 온다.
  Future<void> reorderTabs(int oldIndex, int newIndex) async {
    final current = await future;
    final movable = [
      for (final m in current.tabs)
        if (m.id != ModuleIds.settings) m.id,
    ];
    final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    movable.insert(target, movable.removeAt(oldIndex));
    await _save(
      resolveModules(_catalog, [
        ...movable,
        ModuleIds.settings,
        for (final m in current.cards) m.id,
      ]),
    );
  }

  Future<void> _save(ResolvedModules next) async {
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(installedModulesPrefsKey, jsonEncode(next.ids));
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/core/modules/ && flutter analyze`
Expected: PASS, `No issues found!`

- [ ] **Step 5: 커밋**

```bash
git add lib/core/modules/ lib/features/bus/presentation/providers/bus_providers.dart lib/core/constants/strings/bus_strings.dart test/core/modules/ test/helpers/module_prefs.dart
git commit -m "feat(modules): 등록부와 설치 상태 provider + 버스 켜짐 일회성 이전"
```

---

### Task 3: 탭바가 등록부를 따른다

**Files:**
- Modify: `lib/shared/widgets/main_shell.dart` (`_tabs` 상수 → `tabs` 인자, `indexForLocation`에 `tabs`, 주인 탭 폴백)
- Create: `lib/core/modules/module_shell.dart` (등록부를 읽어 `MainShell`에 탭 목록을 넘기는 얇은 위젯)
- Modify: `lib/core/router/app_router.dart:69-71` (ShellRoute builder → `ModuleShell`)
- Test: `test/shared/main_shell_tab_index_test.dart` (기존 7건 유지 + 추가), `test/core/modules/module_shell_test.dart`

**Interfaces:**
- Consumes: `defaultTabs`·`ModuleTab`(Task 2), `installedModulesProvider`·`moduleCatalogProvider`·`resolveModules`
- Produces:
  - `MainShell({required Widget child, List<ModuleTab> tabs = defaultTabs})`
  - `static int MainShell.indexForLocation(String location, {List<ModuleTab> tabs = defaultTabs})`
  - `class ModuleShell extends ConsumerWidget` (`const ModuleShell({required Widget child})`)
  - `AppRoutes.modules = '/modules'` (라우트 등록은 Task 6)

- [ ] **Step 1: 실패하는 테스트 추가**

`test/shared/main_shell_tab_index_test.dart` 끝(`main`의 마지막 `group` 뒤)에 추가한다. 기존 테스트는 손대지 않는다 — `tabs` 기본값이 지금의 4탭이라 그대로 통과해야 한다.

```dart
  group('탭 하이라이트 — 탭 목록이 바뀔 때', () {
    const extra = ModuleTab(
      route: '/timetable',
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view,
      label: '시간표',
    );

    test('순서가 바뀌면 인덱스도 따라간다', () {
      const tabs = [calendarTab, todayTab, scheduleTab, settingsTab];
      expect(MainShell.indexForLocation(AppRoutes.today, tabs: tabs), 1);
    });

    test('선택 기능 탭도 자기 자신을 켠다', () {
      const tabs = [todayTab, calendarTab, scheduleTab, extra, settingsTab];
      expect(MainShell.indexForLocation('/timetable', tabs: tabs), 3);
      expect(MainShell.indexForLocation(AppRoutes.trash, tabs: tabs), 4);
    });

    test('push 라우트의 주인 탭이 목록에 없으면 -1이 아니라 설정을 켠다', () {
      // 지금은 주인이 전부 고정 탭이라 일어나지 않지만, 선택 기능 탭이 push
      // 라우트를 갖는 순간 생긴다. -1이면 어느 탭도 켜지지 않는다.
      const tabs = [todayTab, calendarTab, settingsTab];
      final i = MainShell.indexForLocation(AppRoutes.import, tabs: tabs);
      expect(i, tabs.indexOf(settingsTab));
    });

    test('기능 관리 화면은 설정을 켠다', () {
      expect(MainShell.indexForLocation(AppRoutes.modules), _settings);
    });
  });
```

파일 맨 위 import에 추가:

```dart
import 'package:flutter/material.dart';
import 'package:planroutine/core/modules/app_module.dart';
import 'package:planroutine/core/modules/module_catalog.dart';
```

```dart
// test/core/modules/module_shell_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/modules/module_shell.dart';
import 'package:planroutine/core/router/app_router.dart';
import 'package:planroutine/shared/widgets/floating_tab_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/module_prefs.dart';

/// **실제 `createRouter`를 쓰지 않는다** — 첫 화면인 오늘 탭이 DB를 읽어
/// fake-async 존에서 멈춘다. 배선(등록부 → 탭바)만 보면 되므로 빈 화면 라우터로 띄운다.
Widget _app() => ProviderScope(
  child: MaterialApp.router(
    routerConfig: GoRouter(
      initialLocation: AppRoutes.today,
      routes: [
        ShellRoute(
          builder: (context, state, child) => ModuleShell(child: child),
          routes: [
            GoRoute(
              path: AppRoutes.today,
              builder: (context, state) => const SizedBox(),
            ),
          ],
        ),
      ],
    ),
  ),
);

List<String> _labels(WidgetTester tester) => tester
    .widget<FloatingTabBar>(find.byType(FloatingTabBar))
    .tabs
    .map((t) => t.label)
    .toList();

void main() {
  testWidgets('로딩 중에는 기본 4탭이 보인다 — 탭바가 비지 않는다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_app());
    // 첫 프레임: provider가 아직 AsyncLoading이다
    expect(_labels(tester), [
      AppStrings.tabToday,
      AppStrings.tabCalendar,
      AppStrings.tabSchedule,
      SettingsStrings.title,
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('저장된 순서대로 탭이 그려진다', (tester) async {
    SharedPreferences.setMockInitialValues(
      modulePrefs(installed: ['calendar', 'today', 'schedule', 'settings']),
    );
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(_labels(tester).first, AppStrings.tabCalendar);
    // 순서가 바뀌어도 지금 화면(오늘)의 탭이 켜진다
    expect(
      tester.widget<FloatingTabBar>(find.byType(FloatingTabBar)).currentIndex,
      1,
    );
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/shared/main_shell_tab_index_test.dart test/core/modules/module_shell_test.dart`
Expected: FAIL — `indexForLocation`에 `tabs` 인자가 없고 `AppRoutes.modules`·`module_shell.dart`가 없다

- [ ] **Step 3: 구현**

`app_router.dart`의 `AppRoutes`에 추가:

```dart
  static const modules = '/modules';
```

```dart
// lib/core/modules/module_shell.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/main_shell.dart';
import 'installed_modules_provider.dart';
import 'module_rules.dart';

/// 등록부를 읽어 `MainShell`에 탭 목록을 넘긴다. `MainShell`이 feature를 모르게
/// 두려고 이 한 겹을 core에 둔다.
///
/// 로딩 중에는 저장값 없이 정리한 값(고정 4탭)을 쓴다 — 탭바가 한 프레임이라도
/// 비면 하단이 깜빡인다.
class ModuleShell extends ConsumerWidget {
  const ModuleShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolved =
        ref.watch(installedModulesProvider).valueOrNull ??
        resolveModules(ref.watch(moduleCatalogProvider), null);
    return MainShell(
      tabs: [for (final m in resolved.tabs) ?m.tab],
      child: child,
    );
  }
}
```

ShellRoute builder(69-71행)를 바꾸고 `../modules/module_shell.dart`를 import한다. `main_shell.dart` import는 더 쓰지 않으면 지운다.

```dart
    ShellRoute(
      builder: (context, state, child) => ModuleShell(child: child),
```

`main_shell.dart`를 바꾼다. `_tabs` 상수를 지우고 아래로 대체한다. `build`의 `_tabs` 참조 둘을 `tabs`로 바꾼다.

```dart
import '../../core/modules/app_module.dart';
import '../../core/modules/module_catalog.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child, this.tabs = defaultTabs});

  final Widget child;

  /// 탭 순서대로. 등록부가 정하고 라우터가 넘긴다 — 이 위젯은 feature를 모른다.
  final List<ModuleTab> tabs;
```

`_pushOwner`에 한 줄 추가:

```dart
    AppRoutes.modules: AppRoutes.settings,
```

`indexForLocation`을 바꾼다:

```dart
  /// 지금 켜야 할 탭. 테스트가 직접 부를 수 있게 static으로 둔다.
  ///
  /// push 라우트의 주인 탭이 [tabs]에 없으면 **설정**을 켠다. -1을 그대로 쓰면
  /// 어느 탭도 켜지지 않는다. 설정은 항상 있고 push 화면 대부분이 설정 소속이라
  /// 가장 덜 어긋난다.
  static int indexForLocation(
    String location, {
    List<ModuleTab> tabs = defaultTabs,
  }) {
    final direct = tabs.indexWhere((tab) => location.startsWith(tab.route));
    if (direct >= 0) return direct;

    // 가장 긴 것부터 본다 — `/bus/settings`와 `/bus/stops`처럼 접두가 겹치는
    // 짝이 있으면 짧은 쪽이 먼저 걸려 엉뚱한 탭을 켠다.
    final keys = _pushOwner.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final key in keys) {
      if (location.startsWith(key)) {
        final owner = tabs.indexWhere((tab) => tab.route == _pushOwner[key]);
        if (owner >= 0) return owner;
        return tabs.indexWhere((tab) => tab.route == AppRoutes.settings);
      }
    }
    return 0;
  }

  int _currentIndex(BuildContext context) =>
      indexForLocation(GoRouterState.of(context).uri.path, tabs: tabs);
```

`FloatingTabItem`을 만드는 `map`은 그대로 두되 `_tabs` → `tabs`로 바꾼다. `MainShell` 위의 주석(`/// 플로팅 탭바를 감싸는 메인 Shell`)은 유지한다. `app_strings.dart` import는 더 이상 필요 없으면 지운다(analyze가 알려준다).

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/shared/ test/core/theme/system_overlay_style_test.dart && flutter analyze`
Expected: PASS(기존 `main_shell_tab_index_test` 7건 포함), `No issues found!`

- [ ] **Step 5: 커밋**

```bash
git add lib/shared/widgets/main_shell.dart lib/core/router/app_router.dart lib/core/modules/module_shell.dart test/shared/ test/core/modules/module_shell_test.dart
git commit -m "feat(modules): 탭바가 등록부의 탭 목록과 순서를 따른다"
```

---

### Task 4: 오늘 탭 카드 자리

**Files:**
- Create: `lib/core/modules/installed_today_cards.dart`
- Modify: `lib/features/today/presentation/widgets/today_body.dart:26,38,58,64` (`busCard` → `cards`)
- Modify: `lib/features/today/presentation/screens/today_screen.dart:8,57`
- Test: `test/core/modules/installed_today_cards_test.dart`

**Interfaces:**
- Consumes: `installedModulesProvider`·`moduleCatalogProvider`(Task 2), `modulePrefs`(Task 2)
- Produces: `class InstalledTodayCards extends ConsumerWidget` (`const InstalledTodayCards()`), `TodayBody({..., Widget? cards})`

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
// test/core/modules/installed_today_cards_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/modules/app_module.dart';
import 'package:planroutine/core/modules/installed_modules_provider.dart';
import 'package:planroutine/core/modules/installed_today_cards.dart';
import 'package:planroutine/core/modules/module_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/module_prefs.dart';

const _cardA = AppModule(
  id: 'a',
  name: 'a',
  icon: Icons.circle,
  placement: ModulePlacement.todayCard,
  card: Text('카드A'),
);
const _cardB = AppModule(
  id: 'b',
  name: 'b',
  icon: Icons.circle,
  placement: ModulePlacement.todayCard,
  card: Text('카드B'),
);

Future<void> _pump(WidgetTester tester) => tester.pumpWidget(
  ProviderScope(
    overrides: [
      moduleCatalogProvider.overrideWithValue([
        ...moduleCatalog.where((m) => m.fixed),
        _cardA,
        _cardB,
      ]),
    ],
    child: const MaterialApp(home: Scaffold(body: InstalledTodayCards())),
  ),
);

void main() {
  testWidgets('로딩 중에는 카드가 없다', (tester) async {
    SharedPreferences.setMockInitialValues(modulePrefs(installed: ['a']));
    await _pump(tester);
    expect(find.text('카드A'), findsNothing);
  });

  testWidgets('켠 카드만 켠 순서대로 그린다', (tester) async {
    SharedPreferences.setMockInitialValues(modulePrefs(installed: ['b', 'a']));
    await _pump(tester);
    await tester.pumpAndSettle();
    final b = tester.getTopLeft(find.text('카드B')).dy;
    final a = tester.getTopLeft(find.text('카드A')).dy;
    expect(b, lessThan(a));
  });

  testWidgets('아무것도 켜지 않았으면 카드가 없다', (tester) async {
    SharedPreferences.setMockInitialValues(modulePrefs());
    await _pump(tester);
    await tester.pumpAndSettle();
    expect(find.text('카드A'), findsNothing);
    expect(find.text('카드B'), findsNothing);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/core/modules/installed_today_cards_test.dart`
Expected: FAIL — `installed_today_cards.dart` 없음

- [ ] **Step 3: 구현**

```dart
// lib/core/modules/installed_today_cards.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'installed_modules_provider.dart';

/// 오늘 탭 맨 위 — 켠 카드형 기능을 켠 순서대로 놓는다.
///
/// **설치 여부는 여기서만 본다.** 카드 위젯(예: `BusCardHost`)은 올라와 있다는
/// 사실이 곧 켜짐이다. 카드 안에서 비동기 provider를 하나 더 기다리게 하면
/// 촉발 순서에 경합이 생긴다(`BusCardHost.initState`의 주석).
/// 로딩 중에는 아무것도 그리지 않는다 — 꺼 둔 사용자에게 카드가 번쩍이면 안 된다.
class InstalledTodayCards extends ConsumerWidget {
  const InstalledTodayCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(installedModulesProvider).valueOrNull?.cards;
    if (cards == null || cards.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final m in cards)
          if (m.card case final card?)
            KeyedSubtree(key: ValueKey(m.id), child: card),
      ],
    );
  }
}
```

`today_body.dart`: 필드 `busCard`를 `cards`로 이름만 바꾼다(생성자 `this.busCard` → `this.cards`, `final busCard = widget.busCard;` → `final cards = widget.cards;`, `?busCard,` → `?cards,`). 필드 주석의 첫 줄을 `/// 목록 맨 위에 얹을 카드들. **null이면 아무것도 그리지 않는다.**`로 바꾸고, `BusCardHost` 이야기는 `InstalledTodayCards`로 바꾼다(그 위젯도 Consumer라 같은 이유가 성립한다).

`today_screen.dart`: `bus_card_host.dart` import를 `../../../../core/modules/installed_today_cards.dart`로 바꾸고 57행을 `cards: const InstalledTodayCards(),`로 바꾼다.

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/core/modules/ test/features/today/ && flutter analyze`
Expected: PASS, `No issues found!`

- [ ] **Step 5: 커밋**

```bash
git add lib/core/modules/installed_today_cards.dart lib/features/today/ test/core/modules/installed_today_cards_test.dart
git commit -m "feat(modules): 오늘 탭이 켠 카드형 기능을 그린다"
```

---

### Task 5: 버스의 켜짐을 등록부로 옮긴다

**Files:**
- Modify: `lib/features/bus/domain/bus_settings.dart` (`enabled` 필드·생성자·`copyWith`·`toJson`·`fromJson`에서 제거)
- Modify: `lib/features/bus/domain/bus_settings_summary.dart`
- Modify: `lib/features/bus/presentation/providers/bus_providers.dart` (`setEnabled` 제거)
- Modify: `lib/features/bus/presentation/widgets/bus_card_host.dart:213,304,363`
- Modify: `lib/features/settings/presentation/widgets/bus_settings_tiles.dart:51-63`
- Modify: `lib/features/settings/presentation/widgets/bus_summary_list_tile.dart`
- Test(다시 겨눔, 선언 수 유지): `test/features/bus/domain/bus_settings_test.dart`, `bus_settings_provider_test.dart`, `bus_settings_summary_test.dart`, `bus_card_host_test.dart`, `bus_card_host_move_test.dart`, `bus_settings_tiles_test.dart`, `bus_slot_tile_long_name_test.dart`, `test/tools/visual_check.dart`

**Interfaces:**
- Consumes: `moduleInstalledProvider`·`installedModulesProvider`·`ModuleIds.bus`·`modulePrefs`·`InstalledTodayCards`
- Produces: `String buildBusSettingsSummary(BusSettings settings, {required bool installed})`

- [ ] **Step 1: 테스트를 새 진실 공급원으로 다시 겨눈다 (아직 컴파일 실패해야 정상)**

각 파일에서 아래처럼 바꾼다. **테스트 선언을 지우지 않는다.**

`domain/bus_settings_test.dart`
- `표시는 꺼져 있고 모양은 간단히다` → 이름을 `모양은 간단히다`로 바꾸고 `enabled` 단정 한 줄을 지운다.
- `전부 채운 값이 왕복한다`·`빈 맵이면 기본값으로 읽힌다`·`clearOverride는 …`에서 `enabled:` 인자와 `enabled` 단정을 지운다.
- 같은 `group` 안에 새 테스트를 하나 더한다(은퇴 가드):

```dart
    test('toJson은 enabled를 쓰지 않는다 — 켜짐의 주인은 등록부다', () {
      // 남겨 두면 누군가 다시 이 값으로 분기를 짠다. 옛 값은
      // migrateLegacyModuleIds만 원본 JSON에서 읽는다.
      expect(BusSettings.defaults.toJson().containsKey('enabled'), isFalse);
    });
```

`bus_settings_provider_test.dart`
- `처음에는 기본값이다 — 꺼져 있고 모양은 간단히` → 이름을 `처음에는 기본값이다 — 모양은 간단히`로, `expect(s.enabled, isFalse);` 삭제.
- `저장한 값이 새 컨테이너에서도 읽힌다`: `await notifier.setEnabled(true);` → `await notifier.setStyle(BusCardStyle.axis);`, `expect(s.enabled, isTrue);` → `expect(s.style, BusCardStyle.axis);` (`bus_card_style.dart` import 추가).
- `겹친 시간대를 읽으면 …나머지는 보존`: `enabled: true,` → `style: BusCardStyle.axis,`, `expect(s.enabled, isTrue);` → `expect(s.style, BusCardStyle.axis);`.
- `손상된 값이면 기본값으로 폴백한다`: `expect(s.enabled, isFalse);` → `expect(s.style, BusSettings.defaults.style);`.

`bus_settings_summary_test.dart` — 켜짐을 `installed:` 인자로 넘긴다.

```dart
    test('꺼져 있으면 꺼짐', () {
      expect(
        buildBusSettingsSummary(BusSettings.defaults, installed: false),
        BusStrings.summaryOff,
      );
    });

    test('켜져 있고 정류장이 없으면 그 사실을 말한다', () {
      expect(
        buildBusSettingsSummary(BusSettings.defaults, installed: true),
        BusStrings.summaryNoStop,
      );
    });
```

나머지 셋도 `copyWith(enabled: …)`의 `enabled`를 지우고 호출에 `installed: true`(마지막 `꺼져 있으면 정류장이 있어도 꺼짐이다`는 `installed: false`)를 넣는다.

`bus_card_host_test.dart`
- `onWithStop`의 `enabled: true,`를 지운다. `_pumpHost`는 호스트를 직접 띄우므로 설치 여부와 무관하다(호스트는 올라와 있으면 켜진 것이다).
- `슬롯이 비면 …`: `BusSettings.defaults.copyWith(enabled: true)` → `BusSettings.defaults`.
- 꺼짐 가드 둘은 **`InstalledTodayCards`를 띄우는 형태로** 다시 겨눈다. 파일에 헬퍼를 더한다:

```dart
/// 오늘 탭의 카드 자리를 띄운다 — 버스 설치 여부가 실제로 갈리는 곳.
Future<int> _pumpTodayCards(
  WidgetTester tester, {
  required DateTime now,
  required BusSettings settings,
  required bool installed,
}) async {
  SharedPreferences.setMockInitialValues(
    modulePrefs(installed: [if (installed) ModuleIds.bus], bus: settings),
  );
  var count = 0;
  final client = BusApiClient(
    client: MockClient((_) async {
      count++;
      return _json(_body());
    }),
    serviceKey: 'TESTKEY',
    clock: () => now,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [busApiClientProvider.overrideWithValue(client)],
      child: const MaterialApp(home: Scaffold(body: InstalledTodayCards())),
    ),
  );
  await tester.pumpAndSettle();
  return count;
}
```

  그리고 두 테스트의 본문을 바꾼다(이름도 바꾼다):

```dart
    testWidgets('버스를 켜지 않았으면 카드가 없고 요청도 0이다', (tester) async {
      final n = await _pumpTodayCards(
        tester,
        now: inRange,
        settings: BusSettings.defaults,
        installed: false,
      );
      expect(find.byType(BusArrivalCard), findsNothing);
      expect(n, 0);
    });
```

```dart
    testWidgets('꺼져 있고 슬롯이 남아 있어도 요청은 0이다 — 켜본 뒤 끈 사용자', (tester) async {
      // 프로덕션의 가장 흔한 OFF 상태는 슬롯이 남아 있는 이 조합이다(켜서 정류장을
      // 등록한 뒤 끈 사용자). 끄더라도 데이터를 지우지 않으므로 정류장은 그대로 남고,
      // 그때 카드가 마운트되면 화면에 1픽셀도 없는데 TAGO를 두드린다.
      final n = await _pumpTodayCards(
        tester,
        now: inRange,
        settings: onWithStop,
        installed: false,
      );
      expect(find.byType(BusArrivalCard), findsNothing);
      expect(n, 0);
    });
```

  import에 `package:planroutine/core/modules/app_module.dart`, `.../core/modules/installed_today_cards.dart`, `../../helpers/module_prefs.dart`를 더한다.

`bus_card_host_move_test.dart` — 세 곳의 `enabled: true,`를 지운다(호스트를 직접 띄운다).

`bus_settings_tiles_test.dart` — **바꿀 것이 없어야 한다.** 빈 prefs에서 시작해 스위치를 탭하면 등록부에 버스가 설치되고 줄이 나타난다. 문구(`꺼져 있어 오늘 탭이 지금과 같습니다`)도 그대로다. 실행해서 확인만 한다.

`bus_slot_tile_long_name_test.dart` — `enabled: true,`를 지우고 prefs를 `modulePrefs(installed: [ModuleIds.bus], bus: settings)`로 바꾼다.

`test/tools/visual_check.dart` — `busPrefs`의 `enabled: true,`를 지우고, 그 값을 prefs에 넣는 곳에 `installedModulesPrefsKey: '["bus"]'`를 함께 넣는다. 이 파일은 `flutter test`가 자동으로 스캔하지 않으므로 **`flutter analyze`로만 걸린다.**

- [ ] **Step 2: 실패 확인**

Run: `flutter analyze`
Expected: `buildBusSettingsSummary`의 `installed` 인자 없음, `InstalledTodayCards` 쪽은 통과. (`enabled`는 아직 모델에 있어 지운 쪽은 문제없다.)

Run: `flutter test test/features/bus/domain/bus_settings_test.dart`
Expected: FAIL — `toJson은 enabled를 쓰지 않는다`

- [ ] **Step 3: 구현**

`bus_settings.dart`: 생성자 `this.enabled = false,`, 필드와 그 주석, `copyWith`의 `bool? enabled,`와 `enabled: enabled ?? this.enabled,`, `toJson`의 `'enabled': enabled,`, `fromJson`의 `enabled: …` 줄을 지운다. 클래스 주석 끝에 한 줄을 더한다:

```dart
/// 켜짐 여부는 여기 없다 — 기능 등록부(`installedModulesProvider`)가 주인이다.
```

`bus_settings_summary.dart`:

```dart
/// **켜짐 여부를 먼저 본다.** 꺼 둔 사용자의 설정에도 정류장은 남아 있으므로,
/// 정류장 수를 먼저 보면 꺼진 기능이 켜진 것처럼 읽힌다. 켜짐은 등록부가
/// 정하므로 인자로 받는다.
String buildBusSettingsSummary(
  BusSettings settings, {
  required bool installed,
}) {
  if (!installed) return BusStrings.summaryOff;
```

`bus_providers.dart`: `setEnabled` 메서드를 지운다.

`bus_card_host.dart`:
- 213행: `final shouldPoll = stop != null && display.expanded;`
- 304행: `return settings.stopFor(display.direction) != null && display.expanded;`
- 363행: `if (settings == null) return const SizedBox.shrink();`
- `_shouldPoll` 위 주석의 "셋 중 하나라도"를 "둘 중 하나라도"로 고치고, 클래스 주석에 한 줄 더한다: `/// 켜짐 여부는 보지 않는다 — 올라와 있다는 것이 곧 켜짐이다(InstalledTodayCards).`

`bus_settings_tiles.dart`: 스위치를 등록부에 묶는다. import에 `../../../../core/modules/app_module.dart`, `../../../../core/modules/installed_modules_provider.dart`를 더한다.

```dart
    final settings =
        ref.watch(busSettingsProvider).valueOrNull ?? BusSettings.defaults;
    // 켜짐은 등록부가 주인이다 — `기능 관리` 화면의 스위치와 같은 값을 본다.
    final installed = ref.watch(moduleInstalledProvider(ModuleIds.bus));
    final notifier = ref.read(busSettingsProvider.notifier);
```

```dart
        SwitchListTile(
          key: switchKey,
          value: installed,
          onChanged: (v) => ref
              .read(installedModulesProvider.notifier)
              .setEnabled(ModuleIds.bus, v),
          title: Text(BusStrings.showTitle, style: _titleStyle),
          subtitle: Text(
            installed ? BusStrings.showSubtitleOn : BusStrings.showSubtitleOff,
            style: _subStyle,
          ),
        ),
        if (installed) ...[
```

클래스 주석의 "스위치가 꺼져 있으면 나머지 줄을 감춘다"는 그대로 두고, 34행 근처 주석의 "기본값이 `enabled: false`라"를 "등록부가 로딩 중이면 `moduleInstalledProvider`가 false라"로 고친다.

`bus_summary_list_tile.dart`:

```dart
    final installed = ref.watch(moduleInstalledProvider(ModuleIds.bus));
    ...
            buildBusSettingsSummary(settings, installed: installed),
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/features/bus/ test/core/modules/ && flutter analyze`
Expected: PASS, `No issues found!`. `bus_settings_tiles_test.dart`는 **수정 없이** 통과해야 한다 — 통과하지 않으면 스위치 배선이 틀린 것이다.

Run: `grep -rn "\.enabled\b" lib/features/bus lib/features/settings/presentation/widgets/bus_*`
Expected: 결과 없음

- [ ] **Step 5: 커밋**

```bash
git add lib/features/bus/ lib/features/settings/presentation/widgets/bus_settings_tiles.dart lib/features/settings/presentation/widgets/bus_summary_list_tile.dart test/features/bus/ test/tools/visual_check.dart
git commit -m "refactor(bus): 켜짐 여부를 기능 등록부로 옮긴다 — BusSettings.enabled 은퇴"
```

---

### Task 6: `기능 관리` 화면과 진입점

**Files:**
- Create: `lib/features/settings/presentation/screens/modules_screen.dart`
- Create: `lib/features/settings/presentation/widgets/modules_list_tile.dart`
- Modify: `lib/features/settings/presentation/screens/settings_screen.dart` (테마 다음에 섹션 추가)
- Modify: `lib/core/router/app_router.dart` (`/modules` GoRoute)
- Modify: `lib/core/constants/strings/settings_strings.dart`
- Test: `test/features/settings/modules_screen_test.dart`

**Interfaces:**
- Consumes: `installedModulesProvider`(`setEnabled`·`reorderTabs`), `moduleCatalogProvider`, `kMaxTabs`, `ModuleIds`, `BusSettingsTiles.switchKey`
- Produces: `ModulesScreen`(`static Key switchKey(String id)`, `static Key tabRowKey(String id)`, `static const lockIconKey`), `ModulesListTile`(`static const tileKey`)

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
// test/features/settings/modules_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/modules/app_module.dart';
import 'package:planroutine/core/modules/installed_modules_provider.dart';
import 'package:planroutine/core/modules/module_catalog.dart';
import 'package:planroutine/features/settings/presentation/screens/modules_screen.dart';
import 'package:planroutine/features/settings/presentation/widgets/bus_settings_tiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/module_prefs.dart';

AppModule _tabModule(String id) => AppModule(
  id: id,
  name: '기능$id',
  description: '설명$id',
  icon: Icons.circle,
  placement: ModulePlacement.tab,
  tab: ModuleTab(
    route: '/$id',
    icon: Icons.circle_outlined,
    activeIcon: Icons.circle,
    label: id,
  ),
);

final _catalog = [
  ...moduleCatalog,
  _tabModule('t1'),
  _tabModule('t2'),
  _tabModule('t3'),
];

Future<void> _pump(
  WidgetTester tester, {
  List<String> installed = const [],
  double width = 390,
  Widget? extra,
}) async {
  SharedPreferences.setMockInitialValues(modulePrefs(installed: installed));
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [moduleCatalogProvider.overrideWithValue(_catalog)],
      child: MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const Expanded(child: ModulesScreen()),
              ?extra,
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Rect _rect(WidgetTester tester, String id) =>
    tester.getRect(find.byKey(ModulesScreen.switchKey(id)));

void main() {
  testWidgets('선택 기능은 켜고 꺼도 같은 자리에 머문다', (tester) async {
    await _pump(tester);
    final before = _rect(tester, ModuleIds.bus);
    await tester.tap(find.byKey(ModulesScreen.switchKey(ModuleIds.bus)));
    await tester.pumpAndSettle();
    expect(_rect(tester, ModuleIds.bus), before);
  });

  testWidgets('탭형을 켜면 내 탭에 설정 바로 앞으로 나타난다', (tester) async {
    await _pump(tester);
    expect(find.byKey(ModulesScreen.tabRowKey('t1')), findsNothing);
    await tester.tap(find.byKey(ModulesScreen.switchKey('t1')));
    await tester.pumpAndSettle();
    final t1 = tester.getTopLeft(find.byKey(ModulesScreen.tabRowKey('t1')));
    final settings = tester.getTopLeft(
      find.byKey(ModulesScreen.tabRowKey(ModuleIds.settings)),
    );
    expect(t1.dy, lessThan(settings.dy));
  });

  testWidgets('탭이 6개면 꺼진 탭형 스위치가 비활성이고 안내가 뜬다', (tester) async {
    await _pump(tester, installed: ['t1', 't2']);
    final sw = tester.widget<SwitchListTile>(
      find.byKey(ModulesScreen.switchKey('t3')),
    );
    expect(sw.onChanged, isNull);
    expect(find.text(SettingsStrings.modulesTabsFull(kMaxTabs)), findsOneWidget);
    // 켜져 있는 탭형과 카드형은 계속 누를 수 있다
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(ModulesScreen.switchKey('t1')))
          .onChanged,
      isNotNull,
    );
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(ModulesScreen.switchKey(ModuleIds.bus)),
          )
          .onChanged,
      isNotNull,
    );
  });

  testWidgets('고정 탭에는 자물쇠가 붙고 고정 기능은 스위치 목록에 없다', (tester) async {
    await _pump(tester);
    expect(find.byKey(ModulesScreen.lockIconKey), findsNWidgets(4));
    expect(find.byKey(ModulesScreen.switchKey(ModuleIds.today)), findsNothing);
  });

  testWidgets('설정 행은 드래그 대상이 아니라 맨 아래에 있다', (tester) async {
    await _pump(tester);
    final settingsRow = find.byKey(ModulesScreen.tabRowKey(ModuleIds.settings));
    expect(
      find.ancestor(of: settingsRow, matching: find.byType(ReorderableListView)),
      findsNothing,
    );
  });

  testWidgets('드래그로 순서를 바꾸면 저장된다', (tester) async {
    await _pump(tester);
    final handle = find.descendant(
      of: find.byKey(ModulesScreen.tabRowKey(ModuleIds.today)),
      matching: find.byIcon(Icons.drag_handle),
    );
    final drag = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(kLongPressTimeout);
    await drag.moveBy(const Offset(0, 120));
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ModulesScreen)),
    );
    final ids = container.read(installedModulesProvider).requireValue.tabs
        .map((m) => m.id);
    expect(ids.first, isNot(ModuleIds.today));
    expect(ids.last, ModuleIds.settings);
  });

  testWidgets('버스 상세 스위치와 기능 관리 스위치가 같은 값을 본다', (tester) async {
    await _pump(
      tester,
      extra: const SizedBox(height: 400, child: BusSettingsTiles()),
    );
    await tester.tap(find.byKey(BusSettingsTiles.switchKey));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(ModulesScreen.switchKey(ModuleIds.bus)),
          )
          .value,
      isTrue,
    );
  });

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('${width.toInt()}pt에서 넘치지 않는다', (tester) async {
      await _pump(tester, installed: ['t1', 't2'], width: width);
      expect(tester.takeException(), isNull);
    });
  }
}
```

> 드래그 테스트는 `ReorderableDragStartListener`가 즉시 드래그를 시작하므로 `kLongPressTimeout` 대기가 필요 없을 수 있다. 실패하면 대기 줄을 지우고 다시 돌린다 — 그래도 실패하면 기대가 아니라 핸들 배선을 의심할 것.

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/settings/modules_screen_test.dart`
Expected: FAIL — `modules_screen.dart` 없음

- [ ] **Step 3: 구현**

`settings_strings.dart`의 화면 테마 묶음 아래에 추가:

```dart
  // 기능 관리
  static const modulesTitle = '기능 관리';
  static const modulesMyTabs = '내 탭';
  static const modulesFeatures = '기능';
  static const modulesEmpty = '아직 추가할 수 있는 기능이 없어요';
  static const placementTab = '탭';
  static const placementTodayCard = '오늘 카드';
  static String modulesTabCount(int n, int max) => '$n/$max';
  static String modulesTabsFull(int max) => '탭이 가득 찼어요 ($max/$max)';
  static String modulesSummary(int n) => n == 0 ? '추가한 기능 없음' : '$n개 사용 중';
```

```dart
// lib/features/settings/presentation/screens/modules_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/modules/app_module.dart';
import '../../../../core/modules/installed_modules_provider.dart';
import '../../../../core/modules/module_rules.dart';
import '../../../../core/theme/app_text_styles.dart';

/// `설정 › 기능 관리` — 선택 기능을 켜고 끄고, 탭 순서를 바꾼다.
///
/// **켜고 꺼도 항목이 자리를 옮기지 않는다.** 아래 `기능` 목록은 켜짐과 무관하게
/// 등록부 순서 그대로다 — 버튼으로 "추가"하면 항목이 위 섹션으로 옮겨 가 누른
/// 자리에서 사라진다(오늘 탭 완료 토글을 재정렬하지 않는 것과 같은 원칙).
/// 끄더라도 데이터는 남으므로 확인 다이얼로그가 없다.
class ModulesScreen extends ConsumerWidget {
  const ModulesScreen({super.key});

  static Key switchKey(String id) => Key('module_switch_$id');
  static Key tabRowKey(String id) => Key('module_tab_$id');
  static const lockIconKey = Key('module_lock');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(moduleCatalogProvider);
    final resolved =
        ref.watch(installedModulesProvider).valueOrNull ??
        resolveModules(catalog, null);
    final notifier = ref.read(installedModulesProvider.notifier);

    final movable = [
      for (final m in resolved.tabs)
        if (m.id != ModuleIds.settings) m,
    ];
    final settings = resolved.tabs.last;
    final optional = [for (final m in catalog) if (!m.fixed) m];
    final tabsFull = resolved.tabs.length >= kMaxTabs;
    final installedIds = resolved.ids.toSet();

    return Scaffold(
      appBar: AppBar(
        title: Text(SettingsStrings.modulesTitle, style: AppTextStyles.heading),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSizes.spacing24),
        children: [
          _header(
            SettingsStrings.modulesMyTabs,
            trailing: SettingsStrings.modulesTabCount(
              resolved.tabs.length,
              kMaxTabs,
            ),
          ),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorder: notifier.reorderTabs,
            children: [
              for (final (i, m) in movable.indexed)
                ListTile(
                  key: tabRowKey(m.id),
                  leading: ReorderableDragStartListener(
                    index: i,
                    child: Icon(Icons.drag_handle, color: AppColors.sub),
                  ),
                  title: Text(m.name),
                  trailing: m.fixed ? _lock() : null,
                ),
            ],
          ),
          // 설정은 드래그 목록 밖에 둔다 — 늘 맨 끝이라 옮길 수 없다.
          ListTile(
            key: tabRowKey(settings.id),
            leading: const SizedBox(width: 24),
            title: Text(settings.name),
            trailing: _lock(),
          ),
          const Divider(),
          _header(SettingsStrings.modulesFeatures),
          if (optional.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSizes.pagePadding),
              child: Text(
                SettingsStrings.modulesEmpty,
                style: TextStyle(color: AppColors.sub),
              ),
            ),
          for (final m in optional)
            _moduleTile(
              m,
              installed: installedIds.contains(m.id),
              blocked:
                  tabsFull &&
                  m.placement == ModulePlacement.tab &&
                  !installedIds.contains(m.id),
              onChanged: (v) => notifier.setEnabled(m.id, v),
            ),
        ],
      ),
    );
  }

  Widget _lock() =>
      Icon(Icons.lock_outline, key: lockIconKey, size: 18, color: AppColors.faint);

  Widget _header(String title, {String? trailing}) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSizes.pagePadding,
      AppSizes.spacing16,
      AppSizes.pagePadding,
      AppSizes.spacing4,
    ),
    child: Row(
      children: [
        Expanded(child: Text(title, style: AppTextStyles.eyebrow)),
        if (trailing != null)
          Text(trailing, style: TextStyle(fontSize: 14, color: AppColors.sub)),
      ],
    ),
  );

  /// 스위치에 `activeThumbColor`를 주지 않는다 — 전역 `switchTheme` 색 가드.
  Widget _moduleTile(
    AppModule m, {
    required bool installed,
    required bool blocked,
    required ValueChanged<bool> onChanged,
  }) {
    final placement = m.placement == ModulePlacement.tab
        ? SettingsStrings.placementTab
        : SettingsStrings.placementTodayCard;
    return SwitchListTile(
      key: switchKey(m.id),
      secondary: Icon(m.icon, color: AppColors.primary),
      title: Text(m.name),
      subtitle: Text(
        blocked
            ? '$placement · ${m.description}\n${SettingsStrings.modulesTabsFull(kMaxTabs)}'
            : '$placement · ${m.description}',
      ),
      isThreeLine: blocked,
      value: installed,
      onChanged: blocked ? null : onChanged,
    );
  }
}
```

> `AppColors.primary`·`AppTextStyles.eyebrow`·`AppSizes.pagePadding`·`spacing16`·`spacing4`·`spacing24`는 이미 리포에 있다(`bus_summary_list_tile.dart`·`today_screen.dart`가 쓴다). 화면이 **본문 15pt / 메타 14pt** 규칙을 따르는지 시뮬레이터에서 본다.

```dart
// lib/features/settings/presentation/widgets/modules_list_tile.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/modules/installed_modules_provider.dart';
import '../../../../core/router/app_router.dart';

/// 설정 탭의 `기능 관리` 한 줄. 모양은 `BusSummaryListTile`과 같다
/// (아이콘 + 제목 + 현재 상태 + chevron).
class ModulesListTile extends ConsumerWidget {
  const ModulesListTile({super.key});

  static const tileKey = Key('modules_tile');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolved = ref.watch(installedModulesProvider).valueOrNull;
    final count = resolved == null
        ? 0
        : [...resolved.tabs, ...resolved.cards].where((m) => !m.fixed).length;

    return ListTile(
      key: tileKey,
      leading: Icon(Icons.extension_outlined, color: AppColors.primary),
      title: const Text(SettingsStrings.modulesTitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            SettingsStrings.modulesSummary(count),
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
      onTap: () => context.push(AppRoutes.modules),
    );
  }
}
```

`settings_screen.dart`: `ThemeModeTile` 섹션 바로 다음 줄에 `const SettingsSection(child: ModulesListTile()),`와 import를 더한다.

`app_router.dart`: `AppRoutes.busSettings` GoRoute 바로 앞에 추가하고 `ModulesScreen` import를 더한다.

```dart
        // 설정 탭에서 push. Shell 안에 둬야 탭바가 남는다.
        GoRoute(
          path: AppRoutes.modules,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ModulesScreen()),
        ),
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/features/settings/ test/shared/ && flutter analyze`
Expected: PASS, `No issues found!`

- [ ] **Step 5: 커밋**

```bash
git add lib/features/settings/ lib/core/router/app_router.dart lib/core/constants/strings/settings_strings.dart test/features/settings/modules_screen_test.dart
git commit -m "feat(modules): 기능 관리 화면 — 스위치로 켜고 끄고 탭 순서 변경"
```

---

### Task 7: 등록부 가드와 6탭 폭

**Files:**
- Test: `test/core/modules/module_catalog_test.dart`
- Test: `test/shared/floating_tab_bar_six_tabs_test.dart`

**Interfaces:**
- Consumes: `moduleCatalog`, `ModuleIds`, `createRouter`, `FloatingTabBar`·`FloatingTabItem`

- [ ] **Step 1: 테스트 작성**

```dart
// test/core/modules/module_catalog_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planroutine/core/modules/app_module.dart';
import 'package:planroutine/core/modules/module_catalog.dart';
import 'package:planroutine/core/router/app_router.dart';

/// **배포한 id 목록.** 여기서 지우려면 이유를 함께 적는다.
///
/// id는 사용자 기기의 저장값이다. 이름을 바꾸거나 지우면 그 기능을 켜 둔
/// 사용자의 설정이 오류도 없이 꺼진다(`resolveModules`가 모르는 id를 버린다).
const _shippedIds = [
  ModuleIds.today,
  ModuleIds.calendar,
  ModuleIds.schedule,
  ModuleIds.settings,
  ModuleIds.bus,
];

List<String> _paths(List<RouteBase> routes) => [
  for (final r in routes) ...[
    if (r is GoRoute) r.path,
    ..._paths(r.routes),
  ],
];

void main() {
  test('id가 겹치지 않는다', () {
    final ids = moduleCatalog.map((m) => m.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('배포한 id가 등록부에 모두 남아 있다', () {
    final ids = moduleCatalog.map((m) => m.id).toSet();
    for (final id in _shippedIds) {
      expect(ids, contains(id), reason: '$id를 지우면 켜 둔 사용자의 설정이 조용히 꺼진다');
    }
  });

  test('고정 기능은 정확히 오늘·캘린더·입력·설정이다', () {
    expect(
      moduleCatalog.where((m) => m.fixed).map((m) => m.id).toSet(),
      {ModuleIds.today, ModuleIds.calendar, ModuleIds.schedule, ModuleIds.settings},
    );
  });

  test('자리와 그 자리의 재료가 짝이 맞는다', () {
    for (final m in moduleCatalog) {
      final isTab = m.placement == ModulePlacement.tab;
      expect(m.tab != null, isTab, reason: '${m.id}: tab');
      expect(m.card != null, !isTab, reason: '${m.id}: card');
    }
  });

  test('탭형 기능의 라우트는 설치 여부와 무관하게 라우터에 있다', () {
    final paths = _paths(createRouter(onboardingDone: true).configuration.routes);
    for (final m in moduleCatalog) {
      final route = m.tab?.route;
      if (route == null) continue;
      expect(paths, contains(route), reason: '${m.id}의 라우트가 없으면 Page Not Found');
    }
  });

  test('선택 기능은 설명을 갖는다 — 기능 관리 화면에 빈 줄이 뜨지 않게', () {
    for (final m in moduleCatalog.where((m) => !m.fixed)) {
      expect(m.description, isNotEmpty, reason: m.id);
    }
  });
}
```

```dart
// test/shared/floating_tab_bar_six_tabs_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/shared/widgets/floating_tab_bar.dart';

const _labels = [
  AppStrings.tabToday,
  AppStrings.tabCalendar,
  AppStrings.tabSchedule,
  '시간표',
  '여섯째',
  SettingsStrings.title,
];

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('6탭이 ${width.toInt()}pt에서 넘치지 않고 라벨이 한 줄이다', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: FloatingTabBar(
              currentIndex: 0,
              onTap: (_) {},
              tabs: [
                for (final l in _labels)
                  FloatingTabItem(
                    icon: Icons.circle_outlined,
                    activeIcon: Icons.circle,
                    label: l,
                  ),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      // 가장 긴 라벨(`캘린더`)이 한 줄 높이를 넘지 않는다
      final h = tester.getSize(find.text(AppStrings.tabCalendar)).height;
      expect(h, lessThan(20));
    });
  }
}
```

- [ ] **Step 2: 실행**

Run: `flutter test test/core/modules/module_catalog_test.dart test/shared/floating_tab_bar_six_tabs_test.dart`
Expected: PASS. 실패하면 가드가 아니라 등록부·라우터를 고친다.

- [ ] **Step 3: 가드가 회귀를 실제로 잡는지 확인**

`module_catalog.dart`에서 `ModuleIds.bus` 항목을 잠시 지우고 `flutter test test/core/modules/module_catalog_test.dart`를 돌려 `배포한 id가 …`가 실패하는지 본 뒤 되돌린다. 커밋하지 않는다.

- [ ] **Step 4: 커밋**

```bash
git add test/core/modules/module_catalog_test.dart test/shared/floating_tab_bar_six_tabs_test.dart
git commit -m "test(modules): 등록부 가드(배포 id·라우트 등록) + 6탭 폭"
```

---

### Task 8: 전체 검증, 런타임 확인, 문서

**Files:**
- Modify: `CLAUDE.md` (핵심 기능, 기술 스택의 라우팅·영구 설정 행, 설정 탭 섹션 수, 테스트 건수, 새 절 `### 기능 모듈`)
- Modify: `docs/superpowers/specs/2026-10-02-feature-modules-design.md` ("Spec과 다른 점" 4개 반영)
- Modify: 옵시디언 `스펙/2026-10-02 기능 모듈 — 고정 탭 + 선택 기능.md` (같은 반영)

- [ ] **Step 1: 전체 테스트와 정적 검사**

Run: `flutter analyze && flutter test`
Expected: `No issues found!`, 전체 통과. 건수를 기록한다(직전 1151 + 이번 추가분).

- [ ] **Step 2: 업그레이드 실측 (Review Focus 1, 반드시 밟는다)**

1. `git stash`가 필요 없게 깨끗한 상태에서 `git worktree add ../planroutine-old ab5d518`(이 계획 이전 커밋)로 옛 빌드를 만든다.
2. 옛 빌드를 iPhone 시뮬레이터에 설치·실행 → 설정 › 버스 도착 › 표시 켜기 → 정류장 하나 등록 → 오늘 탭에 카드가 보이는지 확인.
3. 앱을 지우지 않고 새 빌드를 같은 시뮬레이터에 설치·실행(`flutter run`은 데이터를 보존한다).
4. **오늘 탭에 버스 카드가 그대로 보이는지**, 설정 › 기능 관리에서 출퇴근 버스 스위치가 켜져 있는지 확인. 스크린샷을 남긴다.
5. `git worktree remove ../planroutine-old`.

- [ ] **Step 3: 화면 동작 실측**

시뮬레이터에서: 기능 관리 진입(탭바에 설정이 켜져 있는지) → 버스 스위치 끄기(오늘 탭 카드가 사라지는지, 설정의 `버스 도착` 행이 `꺼짐`으로 남는지) → 다시 켜기(정류장이 그대로인지) → 내 탭에서 오늘을 캘린더 뒤로 드래그(탭바 순서가 바뀌는지) → 앱 재시작 후 순서 유지. 라이트·다크 둘 다 본다(라이트에서 자물쇠·드래그 핸들 대비).

- [ ] **Step 4: 기존 E2E**

Run: `flutter test integration_test/app_test.dart -d <시뮬레이터 id>`
Expected: 19건 통과(기본 상태가 지금의 4탭과 같다).

- [ ] **Step 5: 문서**

CLAUDE.md:
- 핵심 기능에 `13. **기능 관리** — 고정 4탭 + 스위치로 켜는 선택 기능(탭/오늘 카드). 탭 최대 6, 설정 맨 끝.`을 더한다.
- 기술 스택 라우팅 행: `ShellRoute 4탭` → `ShellRoute 고정 4탭 + 선택 탭(최대 6, 등록부가 정함)`, push 목록에 `/modules`.
- 영구 설정 행에 `기능 설치·탭 순서(installed_modules_v1)`.
- 설정 탭 구조: 섹션 수를 실제로 세어 고친다(`기능` 섹션 1개 추가).
- 새 절 `### 기능 모듈 (등록부)`: 진실 공급원이 등록부 하나라는 것, id는 저장값이라 바꾸지 않는다는 것과 그 가드, 이전은 키 유무로 한 번만, `BusSettings.enabled` 은퇴와 `migrateLegacyModuleIds`가 유일한 독자라는 것, 카드는 `InstalledTodayCards`만 설치 여부를 본다는 것(호스트 경합 이유), 버스 행이 꺼져도 보이는 예외와 그 이유.
- 테스트 건수를 Step 1의 실측값으로 고친다.

스펙: 맨 끝에 `## 계획 단계에서 바뀐 것 (2026-10-02)` 절을 두고 이 계획의 "Spec과 다른 점" 4개를 옮긴다. 옵시디언 사본에도 같은 절을 붙인다.

- [ ] **Step 6: 커밋**

```bash
git add CLAUDE.md docs/superpowers/specs/2026-10-02-feature-modules-design.md
git commit -m "docs: 기능 모듈 — CLAUDE.md 절 추가 + 스펙에 계획 단계 변경 반영"
```

- [ ] **Step 7: 작업 로그 제안**

`document-release` 스킬로 옵시디언 작업 로그를 남길지 사용자에게 묻는다. 배포(시간표와 함께 할지)는 사용자에게 묻는다 — 단축어가 함께 실린다는 점도 알린다(보류 기록의 "남은 미결정").
