// ignore_for_file: avoid_print
//
// App Store 심사용 스크린샷 자동 촬영.
//
// 실행:
//   flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/screenshot_test.dart \
//     -d <UDID>
//
// 결과: docs/screenshots/{1_today,2_calendar,3_schedule,4_import,5_settings}.png
//
// 드라이버가 루트에 쓴다 → App Store 제출용은 규격별 폴더로 옮긴다.
//   6.9" (1320x2868, iPhone 17 Pro Max) → docs/screenshots/appstore/6.9/
//   6.5" (1284x2778, iPhone 12 Pro Max) → docs/screenshots/appstore/6.5/
// 두 규격을 모두 두는 이유: 기존 승인본이 6.5"라 like-for-like 교체가 되고,
// ASC가 6.9"를 요구해도 바로 대응된다.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:planroutine/app.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/core/dev/screenshot_seed.dart';
import 'package:planroutine/features/settings/presentation/providers/stamp_settings_provider.dart';
import 'package:planroutine/shared/widgets/floating_tab_bar.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App Store용 5화면 스크린샷 촬영', (tester) async {
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

    // 1. 오늘 탭 (기본 진입) — 스토어에서는 도장이 선명해야 하므로 '흐리게'를 끈다.
    await container
        .read(stampSettingsProvider.notifier)
        .setDimPreviousStamps(false);
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('1_today');

    // 2. 캘린더 탭
    await tester.tap(find.descendant(
      of: find.byType(FloatingTabBar),
      matching: find.byIcon(Icons.calendar_month_outlined),
    ));
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('2_calendar');

    // 3. 입력 탭
    final scheduleTab = find.descendant(
      of: find.byType(FloatingTabBar),
      matching: find.byIcon(Icons.note_add_outlined),
    );
    await tester.tap(scheduleTab.first);
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await binding.takeScreenshot('3_input');

    // 5. 설정 탭
    final settingsTab = find.descendant(
      of: find.byType(FloatingTabBar),
      matching: find.byIcon(Icons.settings_outlined),
    );
    await tester.tap(settingsTab.first);
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await binding.takeScreenshot('5_settings');

    // 4. 설정 → Import 풀스크린 + 에듀파인 가이드 펼침
    // SectionHeader와 ListTile이 같은 텍스트를 가지므로 아이콘으로 구분
    await tester
        .tap(find.widgetWithIcon(ListTile, Icons.upload_file));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ImportStrings.edufineGuideTitle));
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await binding.takeScreenshot('4_import');
  });
}
