// 쪽지 위 글자는 본문(ink)과 날짜(sub)다. 쪽지 색 넷 × 두 테마에서 4.5:1을 지킨다.
// 라이트는 옅은 색이라 쉽지만, 다크는 어두운 쪽지 위 크림 글자라 따로 잰다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_colors.dart';

import '../../helpers/contrast.dart';

void main() {
  tearDown(() => AppColors.applyBrightness(Brightness.dark));

  for (final b in Brightness.values) {
    test('$b: 쪽지 넷 위의 본문·보조 글자가 4.5:1 이상', () {
      AppColors.applyBrightness(b);
      final fills = {
        'yellow': AppColors.memoYellow,
        'green': AppColors.memoGreen,
        'blue': AppColors.memoBlue,
        'pink': AppColors.memoPink,
      };
      for (final e in fills.entries) {
        expect(contrastRatio(AppColors.ink, e.value), greaterThanOrEqualTo(4.5),
            reason: '${e.key} 위 본문');
        expect(contrastRatio(AppColors.sub, e.value), greaterThanOrEqualTo(4.5),
            reason: '${e.key} 위 보조');
      }
    });

    test('$b: 쪽지 넷이 서로 다르다', () {
      AppColors.applyBrightness(b);
      final set = {
        AppColors.memoYellow,
        AppColors.memoGreen,
        AppColors.memoBlue,
        AppColors.memoPink,
      };
      expect(set, hasLength(4));
    });
  }
}
