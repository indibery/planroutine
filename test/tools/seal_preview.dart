// 완료 도장 4종을 **실제 위젯**으로 렌더해 눈으로 확인한다.
//
// `flutter test test/tools/seal_preview.dart` → `docs/seal_candidates/seals_{1,3}x.png`
// (파일명에 `_test`가 없어 `flutter test` 자동 스캔에서 빠진다 — `gen_app_icon.dart`와 같다.)
//
// **왜 픽셀을 봐야 하나**: 도마뱀 마크는 그림이 아니라 **PNG 에셋**이다. 에셋이 없거나
// `pubspec.yaml` 선언이 빠지면 위젯 트리에는 `Image`가 그대로 있어 위젯 테스트는 통과하고
// **런타임에만** 회색 X로 깨진다. 판다(CustomPainter)에는 없던 실패 경로다.
// 그래서 `RepaintBoundary`로 실제로 칠해진 픽셀을 뽑아 본다.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/features/today/domain/stamp_settings.dart';
import 'package:planroutine/features/today/presentation/widgets/completion_seal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final loader = FontLoader('Pretendard')
      ..addFont(rootBundle.load('assets/fonts/PretendardVariable.ttf'));
    await loader.load();
  });

  for (final brightness in [Brightness.dark, Brightness.light]) {
    final name = brightness == Brightness.dark ? 'dark' : 'light';

    testWidgets('도장 4종 — $name', (tester) async {
      AppColors.applyBrightness(brightness);
      tester.view.physicalSize = const Size(1200, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            child: ColoredBox(
              color: AppColors.background,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final style in SealStyle.values)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CompletionSeal(
                              animation: const AlwaysStoppedAnimation(1),
                              style: style,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              style.label,
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // 에셋 이미지는 비동기로 디코드된다. **`pumpAndSettle`로는 안 된다** —
      // fake-async 존에서는 코덱이 돌지 않아 도마뱀 자리가 빈 채로 캡처된다(실측).
      // `runAsync` 안에서 `precacheImage`로 실제 디코드를 끝내고, 프레임은 존 밖에서 돌린다.
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/images/seal_gecko.png'),
          tester.element(find.byType(CompletionSeal).last),
        );
      });
      await tester.pumpAndSettle();

      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first,
      );
      final dir = Directory('docs/seal_candidates')
        ..createSync(recursive: true);
      for (final scale in [1.0, 3.0]) {
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: scale);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final f = File('${dir.path}/seals_${name}_${scale.toInt()}x.png');
          f.writeAsBytesSync(data!.buffer.asUint8List());
          debugPrint('Wrote ${data.lengthInBytes} bytes → ${f.path}');
        });
      }
    });
  }
}
