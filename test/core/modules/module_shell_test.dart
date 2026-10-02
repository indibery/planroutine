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
