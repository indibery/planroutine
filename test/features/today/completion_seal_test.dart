import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/features/today/domain/stamp_settings.dart';
import 'package:planroutine/features/today/presentation/widgets/completion_seal.dart';

void main() {
  Future<void> pumpSeal(
    WidgetTester tester, {
    required SealStyle style,
    bool dimmed = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CompletionSeal(
              animation: const AlwaysStoppedAnimation(1),
              style: style,
              dimmed: dimmed,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double sealOpacity(WidgetTester tester) {
    return tester
        .widget<Opacity>(
          find.descendant(
            of: find.byType(CompletionSeal),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;
  }

  group('도장 모양', () {
    testWidgets('완료 도장은 "완료" 글자를 찍는다', (tester) async {
      await pumpSeal(tester, style: SealStyle.complete);

      expect(find.text('완료'), findsOneWidget);
    });

    testWidgets('결재 도장은 "결재" 글자를 찍는다', (tester) async {
      await pumpSeal(tester, style: SealStyle.approve);

      expect(find.text('결재'), findsOneWidget);
      expect(find.text('완료'), findsNothing);
    });

    testWidgets('좋아요 도장은 글자 없이 엄지 아이콘을 찍는다', (tester) async {
      await pumpSeal(tester, style: SealStyle.like);

      expect(find.byIcon(Icons.thumb_up_alt_rounded), findsOneWidget);
      expect(find.text('좋아요'), findsNothing);
    });

    testWidgets('글자 도장의 문구는 테두리 안에 들어간다 (넘치면 글자가 깨진다)',
        (tester) async {
      for (final style in SealStyle.values.where((s) => !s.usesIcon)) {
        await pumpSeal(tester, style: style);
        final textWidth = tester.getSize(find.text(style.label)).width;
        expect(
          textWidth,
          lessThanOrEqualTo(CompletionSeal.innerWidth),
          reason: '"${style.label}" 도장 문구가 '
              '${textWidth.toStringAsFixed(1)}로 내부 폭을 넘는다',
        );
      }
    });
  });

  group('이미 찍은 도장 흐리게', () {
    testWidgets('흐리게 옵션이 켜지면 도장이 더 옅게 찍힌다', (tester) async {
      await pumpSeal(tester, style: SealStyle.complete);
      final normal = sealOpacity(tester);

      await pumpSeal(tester, style: SealStyle.complete, dimmed: true);
      final dimmed = sealOpacity(tester);

      expect(dimmed, lessThan(normal));
    });

    testWidgets('흐린 도장도 완전히 사라지지는 않는다', (tester) async {
      await pumpSeal(tester, style: SealStyle.complete, dimmed: true);

      expect(sealOpacity(tester), greaterThan(0.15));
    });
  });
}
