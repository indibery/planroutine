import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/features/today/domain/stamp_settings.dart';
import 'package:planroutine/features/today/presentation/widgets/completion_seal.dart';
import 'package:planroutine/features/today/presentation/widgets/seal_gecko_mark.dart';

void main() {
  group('도마뱀 도장 마크', () {
    test('마크가 도장 내부 폭 안에 들어간다', () {
      // 판다(22)보다 크다 — 속 빈 윤곽선이라 22에서는 선이 1px 미만으로 흐려진다.
      // 28 vs 31.4로 여유 1.7씩.
      expect(
        SealGeckoMark.size,
        lessThanOrEqualTo(CompletionSeal.innerWidth),
        reason:
            '마크 ${SealGeckoMark.size}가 내부 폭 '
            '${CompletionSeal.innerWidth.toStringAsFixed(1)}를 넘는다',
      );
    });

    testWidgets('에셋을 번들에서 읽을 수 있다', (tester) async {
      // 이 마크는 그림이 아니라 **에셋**이라, 파일이 없거나 `pubspec.yaml` 선언이
      // 빠지면 위젯 트리에는 `Image`가 그대로 있어 **위젯 존재 검증은 통과하고**
      // 런타임에만 빈 자리로 깨진다. 판다(CustomPainter)에는 없던 실패 경로다.
      //
      // **파일 존재 확인으로는 부족하다** — 파일이 있어도 pubspec 선언이 빠지면
      // 번들에 안 들어간다. 그래서 실제 로드 경로인 `rootBundle`로 검사한다.
      final data = await rootBundle.load('assets/images/seal_gecko.png');
      expect(data.lengthInBytes, greaterThan(0));

      // 알파 마스크여야 한다 — RGB에 색이 박혀 있으면 `srcIn`이 무의미해지고
      // 라이트 테마에서 대비가 무너진다. PNG IHDR의 색 타입이 6(RGBA)인지 본다.
      final bytes = data.buffer.asUint8List();
      expect(bytes.sublist(1, 4), utf8.encode('PNG'), reason: 'PNG이 아니다');
      // 8바이트 서명 + 길이4 + 타입4 + 폭4 + 높이4 + 비트깊이1 → 25번째가 색 타입
      expect(bytes[25], 6, reason: '색 타입이 RGBA(6)가 아니라 알파가 없다');
    });

    testWidgets('도마뱀을 고르면 글자를 그리지 않는다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CompletionSeal(
                animation: const AlwaysStoppedAnimation(1),
                style: SealStyle.gecko,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(SealGeckoMark), findsOneWidget);
      // 라벨(`도마뱀`)은 설정 화면 표시용이고 도장에는 찍히지 않는다.
      expect(find.text(SealStyle.gecko.label), findsNothing);
    });

    testWidgets('다른 모양에서는 도마뱀을 그리지 않는다', (tester) async {
      for (final style in SealStyle.values.where((s) => s != SealStyle.gecko)) {
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
          find.byType(SealGeckoMark),
          findsNothing,
          reason: '${style.name}에 도마뱀이 그려진다',
        );
      }
    });

    testWidgets('도장 색을 그대로 받아 srcIn으로 입힌다 — 테마 전환에 따라간다', (tester) async {
      // 색을 에셋에 박으면 라이트 팔레트에서 대비가 무너진다. 마스크는 모양만 담고
      // 색은 `AppColors.gold`가 정한다.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CompletionSeal(
                animation: const AlwaysStoppedAnimation(1),
                style: SealStyle.gecko,
              ),
            ),
          ),
        ),
      );

      final mark = tester.widget<SealGeckoMark>(find.byType(SealGeckoMark));
      expect(mark.color, AppColors.gold);

      final image = tester.widget<Image>(
        find.descendant(
          of: find.byType(SealGeckoMark),
          matching: find.byType(Image),
        ),
      );
      expect(image.color, AppColors.gold);
      expect(
        image.colorBlendMode,
        BlendMode.srcIn,
        reason: 'srcIn이 아니면 마스크의 알파가 아니라 원본 색이 나온다',
      );
      expect(image.width, SealGeckoMark.size);
      expect(image.height, SealGeckoMark.size);
    });
  });
}
