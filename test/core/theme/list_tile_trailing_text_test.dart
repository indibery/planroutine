// ListTile 오른쪽(앞뒤) 글자는 테마의 `listTileTheme.leadingAndTrailingTextStyle`이 정한다.
//
// 정하지 않으면 Material 3가 `textTheme.labelSmall`을 쓰는데, 이 앱의 labelSmall은
// 영문 소제목(eyebrow)용으로 **자간 2.5**다. 그래서 설정 탭의 `추가한 기능 없음`·
// `사용 안 함`·`정류장을 등록해 주세요`가 글자 사이가 벌어져 보였다(2026-10-03 사용자 지적).
// 행마다 자간을 고치지 않고 테마 한 곳에서 막는다 — 다음에 만드는 행도 자동으로 맞는다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/core/theme/app_theme.dart';

const _plain = '사용 안 함';
const _sized = '추가한 기능 없음';

Future<void> _pump(WidgetTester tester, Brightness brightness) async {
  AppColors.applyBrightness(brightness);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.of(brightness),
      home: const Scaffold(
        body: Column(
          children: [
            // 스타일을 지정하지 않은 오른쪽 글자 (캘린더 연동 행)
            ListTile(title: Text('제목'), trailing: Text(_plain)),
            // 크기만 지정한 오른쪽 글자 (기능 관리·도장 행) — 자간은 물려받는다
            ListTile(
              title: Text('제목'),
              trailing: Text(_sized, style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ),
    ),
  );
}

TextStyle? _style(WidgetTester tester, String text) => tester
    .widget<RichText>(
      find.descendant(of: find.text(text), matching: find.byType(RichText)),
    )
    .text
    .style;

void main() {
  tearDown(() => AppColors.applyBrightness(Brightness.dark));

  for (final brightness in Brightness.values) {
    testWidgets('$brightness: 행 오른쪽 글자에 자간이 붙지 않는다', (tester) async {
      await _pump(tester, brightness);
      for (final text in [_plain, _sized]) {
        expect(
          _style(tester, text)?.letterSpacing ?? 0,
          0,
          reason: '$text — labelSmall(eyebrow)의 자간 2.5를 물려받으면 글자가 벌어진다',
        );
      }
    });

    testWidgets('$brightness: 스타일 없는 오른쪽 글자도 메타 크기(14)와 보조색이다', (tester) async {
      // labelSmall 그대로면 10pt라 `사용 안 함`만 다른 행보다 작게 보였다.
      await _pump(tester, brightness);
      final style = _style(tester, _plain);
      expect(style?.fontSize, 14);
      expect(style?.color, AppColors.sub);
    });
  }
}
