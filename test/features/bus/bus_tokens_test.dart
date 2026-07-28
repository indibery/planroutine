import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_colors.dart';

void main() {
  tearDown(() => AppColors.applyBrightness(Brightness.dark));

  group('busSignal 토큰 — 두 팔레트에 모두 있고 서로 구별된다', () {
    for (final brightness in Brightness.values) {
      test('$brightness 에서 4색이 모두 다르다', () {
        AppColors.applyBrightness(brightness);
        final colors = {
          AppColors.busSignalNear,
          AppColors.busSignalSoon,
          AppColors.busSignalFar,
          AppColors.busSignalOff,
        };
        expect(colors.length, 4, reason: '같은 색이 섞이면 축 위 점이 구별되지 않는다');
      });
    }

    test('라이트의 soon은 라이트 gold와 다른 값이다', () {
      AppColors.applyBrightness(Brightness.light);
      expect(AppColors.busSignalSoon, isNot(AppColors.gold));
    });
  });
}
