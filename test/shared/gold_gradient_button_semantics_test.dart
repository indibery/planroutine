import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/shared/widgets/gold_gradient_button.dart';

/// `GoldGradientButton`(일정 시트의 `저장`, 가져오기·온보딩의 주 버튼)은 버튼으로 읽혀야 한다.
///
/// `GestureDetector`만 두면 실기 트리에서 `저장`이 그냥 글자로 잡혀 누를 대상으로
/// 보이지 않았다(2026-10-04 실측).
void main() {
  Future<void> pump(
    WidgetTester tester, {
    bool enabled = true,
    VoidCallback? onPressed,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: GoldGradientButton(
            label: '저장',
            enabled: enabled,
            onPressed: onPressed ?? () {},
          ),
        ),
      ),
    ),
  );

  testWidgets('이름 있는 버튼이고 시맨틱스 탭이 onPressed를 부른다', (tester) async {
    final handle = tester.ensureSemantics();
    var pressed = 0;
    await pump(tester, onPressed: () => pressed++);

    expect(
      tester.getSemantics(find.bySemanticsLabel('저장')),
      isSemantics(
        label: '저장',
        isButton: true,
        isEnabled: true,
        hasEnabledState: true,
        hasTapAction: true,
      ),
    );
    tester.semantics.tap(find.semantics.byLabel('저장'));
    expect(pressed, 1);
    handle.dispose();
  });

  testWidgets('꺼져 있으면 비활성 버튼이고 탭 동작이 없다', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, enabled: false);

    expect(
      tester.getSemantics(find.bySemanticsLabel('저장')),
      isSemantics(
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
        hasTapAction: false,
      ),
    );
    handle.dispose();
  });
}
