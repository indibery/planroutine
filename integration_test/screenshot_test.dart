// ignore_for_file: avoid_print
//
// App Store 심사용 스크린샷 자동 촬영.
//
// 실행:
//   flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/screenshot_test.dart \
//     -d <iPhone 12 Pro Max UDID>
//
// 결과: docs/screenshots/{1_calendar,2_schedule,3_import,4_settings}.png

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:planroutine/app.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/core/dev/screenshot_seed.dart';
import 'package:planroutine/shared/widgets/floating_tab_bar.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App Store용 4화면 스크린샷 촬영', (tester) async {
    // DB 초기화 후 seed 주입
    await DatabaseHelper.instance.resetAllData();
    final container = ProviderContainer();
    await seedScreenshotData(container);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const PlanRoutineApp(),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 1. 캘린더 탭 (기본 진입)
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('1_calendar');

    // 2. 일정 탭
    final scheduleTab = find.descendant(
      of: find.byType(FloatingTabBar),
      matching: find.byIcon(Icons.checklist_rtl_outlined),
    );
    await tester.tap(scheduleTab.first);
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await binding.takeScreenshot('2_schedule');

    // 3. 설정 탭
    final settingsTab = find.descendant(
      of: find.byType(FloatingTabBar),
      matching: find.byIcon(Icons.settings_outlined),
    );
    await tester.tap(settingsTab.first);
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await binding.takeScreenshot('4_settings');

    // 4. 설정 → Import 풀스크린 + 에듀파인 가이드 펼침
    // SectionHeader와 ListTile이 같은 텍스트를 가지므로 아이콘으로 구분
    await tester
        .tap(find.widgetWithIcon(ListTile, Icons.upload_file));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ImportStrings.edufineGuideTitle));
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await binding.takeScreenshot('3_import');
  });
}
