import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/features/today/domain/stamp_settings.dart';
import 'package:planroutine/features/today/presentation/widgets/completion_seal.dart';

/// 완료 취소는 **페이드아웃**이어야 한다.
///
/// 도장 낙하는 화면 밖 크기(scale 2.4)에서 시작하므로, 같은 animation을 그대로
/// reverse하면 사라지는 동안 도장이 오히려 부풀어 56px 슬롯을 넘어 제목을 덮는다.
void main() {
  late AnimationController controller;

  Future<void> pumpSeal(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) => CompletionSeal(
                animation: controller,
                style: SealStyle.complete,
              ),
            ),
          ),
        ),
      ),
    );
  }

  double sealOpacity(WidgetTester tester) => tester
      .widget<Opacity>(
        find.descendant(
          of: find.byType(CompletionSeal),
          matching: find.byType(Opacity),
        ),
      )
      .opacity;

  /// 화면에 실제로 그려지는 폭. `getSize`는 레이아웃 크기(44)라 Transform.scale을
  /// 반영하지 않는다 → 변환이 적용되는 전역 사각형으로 재야 한다.
  double sealWidth(WidgetTester tester) => tester
      .getRect(
        find.descendant(
          of: find.byType(CompletionSeal),
          matching: find.byType(Container),
        ),
      )
      .width;

  group('완료 취소 — 페이드아웃', () {
    testWidgets('사라지는 동안 도장이 도장 슬롯(56)보다 커지지 않는다', (tester) async {
      controller = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 460),
        reverseDuration: const Duration(milliseconds: 200),
        value: 1,
      );
      await pumpSeal(tester);

      controller.reverse();
      // reverse 구간을 훑으며 매 프레임 폭을 확인한다.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        expect(
          sealWidth(tester),
          lessThanOrEqualTo(56),
          reason: 'reverse ${controller.value.toStringAsFixed(2)} 지점에서 '
              '${sealWidth(tester).toStringAsFixed(0)}px로 부풀었다',
        );
      }

      controller.stop();
      controller.dispose();
    });

    testWidgets('사라지는 동안 불투명도가 안착값보다 진해지지 않는다', (tester) async {
      controller = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 460),
        reverseDuration: const Duration(milliseconds: 200),
        value: 1,
      );
      await pumpSeal(tester);
      final resting = sealOpacity(tester);

      controller.reverse();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        expect(
          sealOpacity(tester),
          lessThanOrEqualTo(resting + 0.001),
          reason: 'reverse ${controller.value.toStringAsFixed(2)} 지점에서 '
              '${sealOpacity(tester).toStringAsFixed(2)}로 진해졌다',
        );
      }

      controller.stop();
      controller.dispose();
    });

    testWidgets('낙하(forward)는 큰 크기에서 떨어지는 연출을 유지한다', (tester) async {
      controller = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 460),
        value: 0,
      );
      await pumpSeal(tester);

      controller.forward();
      await tester.pump(const Duration(milliseconds: 40));

      // 낙하 초반에는 슬롯보다 크게 보이는 것이 의도된 연출이다.
      expect(sealWidth(tester), greaterThan(56));

      controller.stop();
      controller.dispose();
    });
  });
}
