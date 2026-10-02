import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/modules/app_module.dart';
import 'package:planroutine/core/modules/installed_modules_provider.dart';
import 'package:planroutine/core/modules/module_catalog.dart';
import 'package:planroutine/core/modules/module_rules.dart';
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
      extra: const SizedBox(height: 600, child: BusSettingsTiles()),
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
