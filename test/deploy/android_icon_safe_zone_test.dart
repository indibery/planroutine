import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// 안드로이드 적응형 아이콘 전경이 **안전 원**(108dp 캔버스 중 지름 66dp) 안에 있는지 본다.
///
/// 예전 판단은 로고의 **폭**(59.5dp)을 66dp와 비교해 안전하다고 봤는데, 로고는 사각형이라
/// **대각선**(약 84dp)이 원을 넘었다 — 삼성 테스트폰에서 네 귀퉁이가 잘렸다(2026-10-05).
/// 런처마다 마스크(원·둥근 사각형·물방울)가 다르므로 원 기준으로 지킨다.
void main() {
  test('전경에 칠해진 모든 픽셀이 지름 66dp 안전 원 안에 있다', () {
    final fg = img.decodePng(
      File('assets/icon/app_icon_foreground.png').readAsBytesSync(),
    );
    expect(fg, isNotNull);
    final image = fg ?? img.Image(width: 1, height: 1);
    final cx = image.width / 2;
    final cy = image.height / 2;
    final safeRadius = image.width * 33 / 108;
    var farthest = 0.0;
    for (final p in image) {
      if (p.a > 16) {
        farthest = math.max(
          farthest,
          math.sqrt(math.pow(p.x + 0.5 - cx, 2) + math.pow(p.y + 0.5 - cy, 2)),
        );
      }
    }
    expect(farthest, greaterThan(0), reason: '전경이 비어 있다');
    expect(
      farthest,
      lessThanOrEqualTo(safeRadius),
      reason:
          '로고 끝이 중심에서 ${(farthest / image.width * 108).toStringAsFixed(1)}dp — 안전 원 반지름 33dp를 넘는다. '
          'test/tools/gen_app_icon.dart의 전경 markScale을 줄이고 아이콘을 다시 뽑을 것',
    );
  });
}
