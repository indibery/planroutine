// 스낵바의 **액션 글자가 읽혀야 한다** — 양 테마 AA(4.5:1).
//
// 시뮬레이터 실측(iPhone 17 / iOS 26.5, 2026-09-04): 라이트에서 스낵바 액션이
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
// ⚠️ **발견 경로와 남은 사용처가 다르다.** 처음 눈에 띈 것은 입력 탭 삭제의
// `실행취소`였는데, 그 액션은 같은 날 걷어냈다(다른 삭제 경로에 없어 입력 탭만
// 예외였다). 지금 앱에 남은 `SnackBarAction`은 **캘린더의 `설정에서 켜기`**
// (기기 캘린더 권한 거부) 하나이고, 같은 색을 쓰므로 같은 결함을 안고 있었다 —
// 즉 이 가드는 사라진 기능의 잔재가 아니라 **살아 있는 경로**를 지킨다.
//
// ⚠️ **토큰만 비교하면 안 된다.** 날짜 선택 가드가 두 번 통과했는데 화면은
// 깨져 있었던 적이 있다 — Material이 실제로 칠하는 짝이 아닌 짝을 쟀기 때문이다.
// 그래서 여기서는 스낵바를 **실제로 띄워** 렌더된 글자 색과 그 아래 `Material`이
// 칠한 배경을 읽는다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/core/constants/strings/calendar_integration_strings.dart';
import 'package:planroutine/core/theme/app_theme.dart';

import '../../helpers/contrast.dart';

const _actionLabel = CalendarIntegrationStrings.openSettings;

/// 살아 있는 경로와 **같은 형태**로 띄운다 — 캘린더 권한 스낵바는 헬퍼를 거치지
/// 않고 맨 `SnackBar`를 만든다(그 스낵바는 입력 탭 pill과 무관하다).
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
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('기기 캘린더 권한이 필요합니다'),
                  action: SnackBarAction(label: _actionLabel, onPressed: () {}),
                ),
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

      testWidgets('$themeName — 액션 글자가 배경과 AA(4.5:1)', (tester) async {
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
              '권한을 켜러 갈 길이 사라진다',
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
