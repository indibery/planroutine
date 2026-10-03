// test/shared/floating_tab_bar_six_tabs_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/shared/widgets/floating_tab_bar.dart';

const _labels = [
  AppStrings.tabToday,
  AppStrings.tabCalendar,
  AppStrings.tabSchedule,
  MemoStrings.tabLabel,
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
