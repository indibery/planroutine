// 스낵바의 **액션 글자가 읽혀야 한다** — 양 테마 AA(4.5:1).
//
// 입력 탭의 ← 스와이프 삭제는 `실행취소` 액션이 달린 스낵바를 띄운다. 그 액션이
// 안 보이면 **되돌릴 방법 자체가 없다** — 스낵바를 pill 위로 올린 것도 그것을
// 누를 수 있게 하려는 것이었다(`shared/bulk_bar_snack.dart` 참고).
//
// 시뮬레이터 실측(iPhone 17 / iOS 26.5, 2026-09-04): 라이트에서 `실행취소`가
// **통째로 사라졌다**. 접근성 트리에는 Button이 있는데 그 자리 픽셀이 전부
// 스낵바 배경색 하나였다 — 대비 **1.00:1**.
//
// 기제는 `colorScheme`을 명시 생성자로 만들면서 두 필드를 **안 준 것**이다.
// Material 3 스낵바는 배경에 `inverseSurface`, 액션 글자에 `inversePrimary`를
// 쓰는데(`snack_bar.dart`의 `_SnackbarDefaultsM3`), Flutter의 폴백이
// `inverseSurface ?? onSurface` · `inversePrimary ?? onPrimary`라
// 라이트 팔레트에서 둘 다 `#17253D`(`ink` = `navy`)로 수렴한다.
//
// **다크에서는 안 드러난다** — 거기서는 `ink`(크림)와 `navy`가 다르다. 날짜 선택
// 대비·공휴일 행 채움과 같은 부류로, **이 계열 결함은 라이트로 봐야 보인다.**
//
// ⚠️ **토큰만 비교하면 안 된다.** 날짜 선택 가드가 두 번 통과했는데 화면은
// 깨져 있었던 적이 있다 — Material이 실제로 칠하는 짝이 아닌 짝을 쟀기 때문이다.
// 그래서 여기서는 스낵바를 **실제로 띄워** 렌더된 글자 색과 그 아래 `Material`이
// 칠한 배경을 읽는다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/core/theme/app_theme.dart';
import 'package:planroutine/shared/bulk_bar_snack.dart';

import '../../helpers/contrast.dart';

const _actionLabel = '실행취소';

/// 실제 경로(`showBulkBarSnack`)로 액션 달린 스낵바를 띄운다.
Future<void> _pumpSnackWithAction(
  WidgetTester tester,
  Brightness brightness,
) async {
  AppColors.applyBrightness(brightness);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.of(brightness),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showBulkBarSnack(
                context,
                '일정을 삭제했어요',
                action: SnackBarAction(label: _actionLabel, onPressed: () {}),
              ),
              child: const Text('띄우기'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byType(ElevatedButton));
  await tester.pumpAndSettle();
}

/// 렌더된 액션 글자의 **실제** 색. `TextButton`이 병합한 스타일을 읽어야 한다 —
/// `Text.style`은 여기서 null이다.
Color _renderedActionColor(WidgetTester tester) {
  final richText = tester.widget<RichText>(
    find.descendant(
      of: find.widgetWithText(TextButton, _actionLabel),
      matching: find.byType(RichText),
    ),
  );
  final color = richText.text.style?.color;
  expect(color, isNotNull, reason: '액션 글자에 색이 안 잡혔다');
  return color!;
}

/// 스낵바가 실제로 칠하는 배경. **바깥 `SnackBar` rect가 아니라 그 안의 첫
/// `Material`** 이다(floating이면 바깥 상자는 margin까지 품는다).
Color _renderedSnackBackground(WidgetTester tester) {
  final material = tester.widget<Material>(
    find
        .descendant(of: find.byType(SnackBar), matching: find.byType(Material))
        .first,
  );
  final color = material.color;
  expect(color, isNotNull, reason: '스낵바 Material에 색이 안 잡혔다');
  return color!;
}

void main() {
  group('스낵바 액션 대비', () {
    for (final brightness in Brightness.values) {
      final themeName = brightness == Brightness.light ? '라이트' : '다크';

      testWidgets('$themeName — 실행취소 글자가 배경과 AA(4.5:1)', (tester) async {
        await _pumpSnackWithAction(tester, brightness);

        final fg = _renderedActionColor(tester);
        final bg = _renderedSnackBackground(tester);
        final ratio = contrastRatio(fg, bg);

        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason:
              '$themeName에서 `$_actionLabel`이 스낵바 배경과 '
              '${ratio.toStringAsFixed(2)}:1 이다. 이 액션이 안 보이면 '
              '삭제를 되돌릴 방법이 없다',
        );
      });

      testWidgets('$themeName — 액션 글자가 배경과 같은 색이 아니다', (tester) async {
        // 1.00:1 회귀 직격. 위 AA 검사에 포함되지만, 실패 메시지가
        // "글자가 통째로 사라졌다"를 곧바로 말해주는 편이 진단이 빠르다.
        await _pumpSnackWithAction(tester, brightness);

        expect(
          _renderedActionColor(tester),
          isNot(_renderedSnackBackground(tester)),
          reason: '$themeName에서 액션 글자색이 스낵바 배경색과 같다 — 글자가 사라진다',
        );
      });
    }
  });
}
