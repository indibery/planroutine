import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/modules/app_module.dart';
import 'package:planroutine/features/settings/presentation/widgets/modules_list_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/module_prefs.dart';

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(home: Scaffold(body: ModulesListTile())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('선택 기능이 없으면 요약이 0개 기준 문구다', (tester) async {
    SharedPreferences.setMockInitialValues(modulePrefs(installed: []));
    await _pump(tester);
    expect(find.text(SettingsStrings.modulesSummary(0)), findsOneWidget);
  });

  testWidgets('버스를 설치하면 1개로 센다 — 고정 탭은 세지 않는다', (tester) async {
    SharedPreferences.setMockInitialValues(
      modulePrefs(installed: [ModuleIds.bus]),
    );
    await _pump(tester);
    expect(find.text(SettingsStrings.modulesSummary(1)), findsOneWidget);
  });
}
