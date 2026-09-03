// Material이 그리는 선택 UI는 **`primary`를 채움으로 쓰면 안 된다.**
//
// `colorScheme.primary`는 `AppColors.gold`인데, 라이트에서 그건 **배경 위
// 텍스트·아이콘용 딥골드**(`#9A7415`)다. 그 위에 `onPrimary`(네이비)를 얹으면
// 3.57:1로 날짜가 안 읽힌다(사용자 신고 2026-08-14).
//
// **다크에서는 안 드러난다** — 다크는 `gold`와 `goldFill`이 같은 값이라 우연히
// 맞는다(9.77:1). 그래서 이 가드는 **라이트를 본다.**
//
// 이 앱의 규칙은 이미 `골드 채움 = goldFill + onGold`다. 직접 그리는 곳은 지키는데
// Material 컴포넌트만 `primary`를 거쳐 우회하고 있었다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/core/theme/app_theme.dart';

import '../../helpers/contrast.dart';

void main() {
  group('날짜·시각 선택 대비', () {
    for (final brightness in Brightness.values) {
      test('$brightness — 선택된 날짜가 읽힌다 (AA 4.5:1)', () {
        AppColors.applyBrightness(brightness);
        final theme = AppTheme.of(brightness);
        const selected = {WidgetState.selected};

        final fill = theme.datePickerTheme.dayBackgroundColor!.resolve(
          selected,
        )!;
        final text = theme.datePickerTheme.dayForegroundColor!.resolve(
          selected,
        )!;

        expect(
          contrastRatio(text, fill),
          greaterThanOrEqualTo(4.5),
          reason:
              '선택 채움 위 글씨가 안 읽힌다 — `primary`(텍스트용 딥골드)를 '
              '채움으로 쓰면 라이트에서 3.57:1이 된다',
        );
      });

      // **오늘이면서 선택된 날**이 급소다. Material은 그 칸의 채움을
      // `dayBackgroundColor`로, 글씨를 `todayForegroundColor`로 그린다 — 후자를
      // `gold` 고정으로 두면 골드 위 골드가 돼 숫자가 통째로 사라진다.
      // 실제 렌더로 잡았고, 위 대비 테스트는 이 조합을 안 본다.
      test('$brightness — 오늘이면서 선택된 날도 읽힌다', () {
        AppColors.applyBrightness(brightness);
        final theme = AppTheme.of(brightness);
        const selected = {WidgetState.selected};

        // **Material이 실제로 칠하는 짝을 재야 한다.** 오늘 칸의 채움은
        // `dayBackgroundColor`가 아니라 `todayBackgroundColor`다 — 처음엔 전자를
        // 재서 8.37:1로 통과했는데 화면은 여전히 딥골드 원이었다.
        final todayFill = theme.datePickerTheme.todayBackgroundColor!.resolve(
          selected,
        )!;
        final todayText = theme.datePickerTheme.todayForegroundColor!.resolve(
          selected,
        )!;

        expect(todayFill, AppColors.goldFill);
        expect(
          contrastRatio(todayText, todayFill),
          greaterThanOrEqualTo(4.5),
          reason: '오늘 셀이 선택되면 글씨가 채움과 같은 골드가 된다',
        );
      });

      test('$brightness — 선택 채움은 `goldFill`이다', () {
        AppColors.applyBrightness(brightness);
        final theme = AppTheme.of(brightness);
        const selected = {WidgetState.selected};

        expect(
          theme.datePickerTheme.dayBackgroundColor!.resolve(selected),
          AppColors.goldFill,
          reason: '채움은 `gold`가 아니라 `goldFill`이다 — 라이트에서 둘이 갈린다',
        );
        expect(
          theme.datePickerTheme.dayForegroundColor!.resolve(selected),
          AppColors.onGold,
        );
      });

      test('$brightness — 시각 선택 다이얼도 같은 짝을 쓴다', () {
        AppColors.applyBrightness(brightness);
        final theme = AppTheme.of(brightness);

        expect(theme.timePickerTheme.dialHandColor, AppColors.goldFill);
        // `WidgetStateColor`는 `Color`이면서 상태로 해석된다 — 캐스팅해야 푼다.
        final dialText =
            theme.timePickerTheme.dialTextColor! as WidgetStateColor;
        expect(dialText.resolve({WidgetState.selected}), AppColors.onGold);
      });
    }
  });
}
