import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/presentation/widgets/guidance_badges.dart';

import '../../helpers/contrast.dart';

/// 배지는 테두리형이라 글자색이 곧 배지색이다 — 카드(surface) 위에서 4.5:1을 지킨다.
void main() {
  tearDown(() => AppColors.applyBrightness(Brightness.dark));

  for (final b in Brightness.values) {
    test('$b: 구분·상태 배지 글자가 카드 위에서 4.5:1 이상', () {
      AppColors.applyBrightness(b);
      final colors = {
        for (final k in GuidanceKind.values) k.name: GuidanceKindBadge.colorOf(k),
        for (final s in GuidanceStatus.values) s.name: GuidanceStatusBadge.colorOf(s),
      };
      for (final e in colors.entries) {
        expect(contrastRatio(e.value, AppColors.surface), greaterThanOrEqualTo(4.5),
            reason: e.key);
      }
    });
  }
}
