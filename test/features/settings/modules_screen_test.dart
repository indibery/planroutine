import 'package:flutter/gestures.dart';
import 'dart:ui' show Tristate;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/modules/app_module.dart';
import 'package:planroutine/core/modules/installed_modules_provider.dart';
import 'package:planroutine/core/modules/module_catalog.dart';
import 'package:planroutine/core/modules/module_rules.dart';
import 'package:planroutine/core/router/app_router.dart';
import 'package:planroutine/features/settings/presentation/screens/modules_screen.dart';
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

// 실제 포스트잇 항목은 뺀다 — 이 화면 테스트의 탭형 선택 기능은 아래 t1~t3뿐이다.
final _catalog = [
  ...moduleCatalog.where((m) => m.id != ModuleIds.memo),
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

  testWidgets('꺼진 기능에는 상세 설정 줄이 없고, 행을 누르면 켜진다', (tester) async {
    await _pumpRouted(tester);
    expect(find.byKey(ModulesScreen.settingsKey(ModuleIds.bus)), findsNothing);
    // 행 전체가 스위치다 — 이름을 눌러도 켜진다(앱의 다른 스위치 행과 같다)
    await tester.tap(find.text(BusStrings.moduleName));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(ModulesScreen.switchKey(ModuleIds.bus)),
          )
          .value,
      isTrue,
    );
    expect(find.text('버스상세'), findsNothing);
  });

  testWidgets('켜면 아래에 상세 설정 줄이 생기고 기능의 요약을 보인다', (tester) async {
    await _pumpRouted(tester);
    expect(find.text(BusStrings.summaryNoStop), findsNothing);
    await tester.tap(find.byKey(ModulesScreen.switchKey(ModuleIds.bus)));
    await tester.pumpAndSettle();
    final settings = find.byKey(ModulesScreen.settingsKey(ModuleIds.bus));
    expect(settings, findsOneWidget);
    // 정류장이 없으니 다음 행동을 알린다 — 화면은 옮기지 않는다
    expect(
      find.descendant(of: settings, matching: find.text(BusStrings.summaryNoStop)),
      findsOneWidget,
    );
    expect(find.text('버스상세'), findsNothing);
    // 기능 행 바로 아래에 붙는다 — 두 버튼이 위아래로 떨어진다
    final row = tester.getRect(find.byKey(ModulesScreen.switchKey(ModuleIds.bus)));
    expect(tester.getRect(settings).top, greaterThanOrEqualTo(row.bottom));
  });

  testWidgets('상세 설정 줄을 누르면 상세 화면으로 간다', (tester) async {
    await _pumpRouted(tester, installed: [ModuleIds.bus]);
    await tester.tap(find.byKey(ModulesScreen.settingsKey(ModuleIds.bus)));
    await tester.pumpAndSettle();
    expect(find.text('버스상세'), findsOneWidget);
  });

  testWidgets('기능 행을 눌러도 상세로 가지 않는다 — 켜고 끄기만 한다', (tester) async {
    await _pumpRouted(tester, installed: [ModuleIds.bus]);
    await tester.tap(find.byKey(ModulesScreen.switchKey(ModuleIds.bus)));
    await tester.pumpAndSettle();
    expect(find.text('버스상세'), findsNothing);
    // 그리고 실제로 꺼졌다 — 상세 설정 줄도 함께 사라진다
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(ModulesScreen.switchKey(ModuleIds.bus)),
          )
          .value,
      isFalse,
    );
    expect(find.byKey(ModulesScreen.settingsKey(ModuleIds.bus)), findsNothing);
  });

  testWidgets('상세 설정이 없는 기능은 켜도 상세 설정 줄이 없다', (tester) async {
    // t1은 settingsRoute가 없는 테스트용 탭형 기능이다
    await _pumpRouted(tester, installed: ['t1']);
    expect(find.byKey(ModulesScreen.settingsKey('t1')), findsNothing);
    expect(find.byKey(ModulesScreen.chevronKey('t1')), findsNothing);
  });

  testWidgets('스위치가 기능 이름과 함께 읽힌다 — 무엇을 켜는지 안다', (tester) async {
    // 행 전체를 한 노드로 묶는 SwitchListTile이라 이름·설명·스위치가 함께 읽힌다.
    final handle = tester.ensureSemantics();
    await _pump(tester);
    final node = tester.getSemantics(
      find.byKey(ModulesScreen.switchKey(ModuleIds.bus)),
    );
    expect(node.label, contains(BusStrings.moduleName));
    // 스위치의 켜짐 상태가 같은 노드에 묶여 있다 — 이름과 상태를 한 번에 읽는다.
    expect(node.getSemanticsData().flagsCollection.isToggled, isNot(Tristate.none));
    handle.dispose();
  });

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('${width.toInt()}pt에서 넘치지 않는다', (tester) async {
      await _pump(
        tester,
        installed: ['t1', 't2', ModuleIds.bus],
        width: width,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
