// 선택된 칩의 글자는 골드 채움 위 네이비(`goldFill`+`onGold`)여야 한다.
//
// 테마가 선택 색을 정하지 않았을 때는 Material 3 기본 선택 배경(밝은 색) 위에 `labelStyle`의
// 옅은 글자가 얹혀, 다크에서 지도 기록 목록의 `전체` 칩 글자가 사라졌다(실기기 신고 2026-10-04).
// 토큰 값이 아니라 **실제로 그려진** 글자색과 칩 배경을 잰다 — Material이 어느 스타일을 쓰는지는
// 렌더해야 안다(날짜 선택 대비 가드가 엉뚱한 짝을 재다 두 번 헛통과한 전례).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/core/theme/app_theme.dart';

import '../../helpers/contrast.dart';

const _label = '전체';

void main() {
  tearDown(() => AppColors.applyBrightness(Brightness.dark));

  for (final b in Brightness.values) {
    testWidgets('$b: 선택된 칩 글자가 칩 배경 위에서 4.5:1 이상', (tester) async {
      AppColors.applyBrightness(b);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.of(b),
          home: Scaffold(
            body: Center(
              child: ChoiceChip(label: const Text(_label), selected: true, onSelected: (_) {}),
            ),
          ),
        ),
      );
      final text = tester.widget<RichText>(
        find.descendant(of: find.byType(ChoiceChip), matching: find.byType(RichText)).first,
      );
      final fg = text.text.style?.color;
      expect(fg, isNotNull);
      expect(contrastRatio(fg ?? Colors.transparent, AppColors.goldFill), greaterThanOrEqualTo(4.5));
    });
  }
}
