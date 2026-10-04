// 디자인 통일 점검(2026-10-04)에서 테마 한 곳으로 모은 규칙들.
//
// - 저장 버튼(`ElevatedButton`)은 골드 채움 규칙(`goldFill` + `onGold`)을 따른다. 예전 테마는 채움에
//   `gold`를 써서 라이트에서 딥골드 위 네이비 3.57:1이었다(일정 검토 시트·버스 확인 시트).
// - 목록 행 글자는 제목 15 / 부제 14다(오늘 탭 기준). 테마가 정하지 않아 설정 탭 부제가 12·13,
//   기능 관리가 13으로 화면마다 달랐다.
// - 세그먼트는 style을 주지 않아도 골드 채움 규칙을 따른다. 예전에는 두 곳만 style을 복사해 두고
//   나머지 넷(지도 기록·버스 카드 모양·포스트잇 시트)이 Material 기본 모양이었다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/core/theme/app_theme.dart';

import '../../helpers/text_glyph.dart';

Future<void> _pump(
  WidgetTester tester,
  Brightness brightness,
  Widget child,
) async {
  AppColors.applyBrightness(brightness);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.of(brightness),
      home: Scaffold(body: child),
    ),
  );
}

Color? _fillOf(WidgetTester tester, Finder button) => tester
    .widget<Material>(
      find.descendant(of: button, matching: find.byType(Material)).first,
    )
    .color;

void main() {
  tearDown(() => AppColors.applyBrightness(Brightness.dark));

  for (final brightness in Brightness.values) {
    testWidgets('$brightness: 저장 버튼은 goldFill 채움 위 onGold 글자다', (tester) async {
      await _pump(
        tester,
        brightness,
        ElevatedButton(onPressed: () {}, child: const Text('저장')),
      );
      expect(_fillOf(tester, find.byType(ElevatedButton)), AppColors.goldFill);
      expect(textStyleOf(tester, find.text('저장'))?.color, AppColors.onGold);
    });

    testWidgets('$brightness: 스타일 없는 목록 행은 제목 15 / 부제 14다', (tester) async {
      await _pump(
        tester,
        brightness,
        const ListTile(title: Text('휴지통'), subtitle: Text('삭제한 일정')),
      );
      expect(textStyleOf(tester, find.text('휴지통'))?.fontSize, 15);
      expect(textStyleOf(tester, find.text('삭제한 일정'))?.fontSize, 14);
      expect(textStyleOf(tester, find.text('삭제한 일정'))?.color, AppColors.sub);
    });

    testWidgets('$brightness: 스타일 없는 세그먼트도 골드 채움 규칙을 따른다', (tester) async {
      await _pump(
        tester,
        brightness,
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 0, label: Text('켬')),
            ButtonSegment(value: 1, label: Text('끔')),
          ],
          selected: const {0},
          onSelectionChanged: (_) {},
        ),
      );
      expect(textStyleOf(tester, find.text('켬'))?.color, AppColors.onGold);
      expect(textStyleOf(tester, find.text('끔'))?.color, AppColors.sub);
      final selected = find.ancestor(
        of: find.text('켬'),
        matching: find.byType(Material),
      );
      expect(tester.widget<Material>(selected.first).color, AppColors.goldFill);
    });
  }
}
