import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/features/today/domain/stamp_settings.dart';
import 'package:planroutine/features/today/presentation/widgets/completion_seal.dart';
import 'package:planroutine/features/today/presentation/widgets/seal_panda_mark.dart';

void main() {
  group('판다 도장 마크', () {
    test('마크가 도장 내부 폭 안에 들어간다', () {
      // 글자 도장이 문구 폭 가드를 갖는 것과 같은 이유다 — 넘치면 이중 테두리를
      // 파고든다. 22 vs 31.4로 여유 4.7씩.
      expect(
        SealPandaMark.size,
        lessThanOrEqualTo(CompletionSeal.innerWidth),
        reason:
            '마크 ${SealPandaMark.size}가 내부 폭 '
            '${CompletionSeal.innerWidth.toStringAsFixed(1)}를 넘는다',
      );
    });

    testWidgets('판다 모양을 고르면 글자도 아이콘도 그리지 않는다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CompletionSeal(
                animation: const AlwaysStoppedAnimation(1),
                style: SealStyle.panda,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(SealPandaMark), findsOneWidget);
      // 라벨(`판다`)은 설정 화면 표시용이고 도장에는 찍히지 않는다.
      expect(find.text(SealStyle.panda.label), findsNothing);
    });

    testWidgets('다른 모양에서는 판다를 그리지 않는다', (tester) async {
      for (final style in SealStyle.values.where((s) => s != SealStyle.panda)) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: CompletionSeal(
                  animation: const AlwaysStoppedAnimation(1),
                  style: style,
                ),
              ),
            ),
          ),
        );
        expect(
          find.byType(SealPandaMark),
          findsNothing,
          reason: '${style.name}에 판다가 그려진다',
        );
      }
    });

    testWidgets('도장 색을 그대로 받는다 — 테마 전환에 따라간다', (tester) async {
      // 색을 위젯 안에 박으면 라이트 팔레트에서 대비가 무너진다(도장은
      // `AppColors.gold`를 쓰고 그 값은 팔레트마다 다르다).
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CompletionSeal(
                animation: const AlwaysStoppedAnimation(1),
                style: SealStyle.panda,
              ),
            ),
          ),
        ),
      );

      final mark = tester.widget<SealPandaMark>(find.byType(SealPandaMark));
      expect(mark.color, AppColors.gold);
    });

    testWidgets('그리다가 예외를 던지지 않는다 — 파냄에 레이어가 필요하다', (tester) async {
      // `BlendMode.clear`를 레이어 없이 쓰면 도장 테두리까지 지워지거나 예외가 난다.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                child: SealPandaMark(color: AppColors.gold),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(SealPandaMark)),
        const Size.square(SealPandaMark.size),
      );
    });
  });
}
