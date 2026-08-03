import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:planroutine/features/calendar/presentation/widgets/event_edit_dialog.dart';
import 'package:planroutine/shared/widgets/keyboard_inset.dart';

/// 제목 ↔ 설명 포커스를 오갈 때 시트가 위아래로 튀지 않아야 한다.
///
/// **실측한 근본 원인**(iPhone 17 Pro 시뮬레이터, 통합 테스트):
/// 포커스가 다른 입력칸으로 옮겨가면 iOS가 키보드를 내렸다 다시 올린다.
/// `MediaQuery.viewInsets.bottom`이 335 → 6 → 335으로 붕괴했다 복구되는데,
/// 시트 패딩이 그 값을 1:1로 따라가면 시트 전체가 키보드 높이만큼
/// 떨어졌다 올라온다(실측 진폭 334.8). 스크롤은 무관하다(`maxScrollExtent=0`).
///
/// 순수 Flutter 위젯으로도 재현되므로 우리 코드의 버그는 "붕괴를 그대로 따라간
/// 것"이다. 규칙: **입력 포커스를 쥐고 있는 동안에는 키보드 자리를 내주지 않는다.**
void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR', null);
  });

  testWidgets('포커스를 쥔 채 키보드 인셋이 잠깐 무너져도 시트가 움직이지 않는다',
      (tester) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    addTearDown(tester.view.reset);
    const keyboard = 335.0; // 실측값

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => EventEditDialog.show(
                  context,
                  initialDate: DateTime(2026, 8, 3),
                  allowKindChange: false,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 키보드가 올라온 상태
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard * 3);
    await tester.pumpAndSettle();

    final header = find.text('일정 추가');

    // 제목에 포커스를 준다 — 이 시점부터 시트는 키보드 자리를 쥐고 있어야 한다.
    await tester.tap(find.byType(TextFormField).at(0));
    await tester.pumpAndSettle();
    final settled = tester.getTopLeft(header).dy;

    // 포커스 전환 순간 iOS가 만드는 일시적 인셋 붕괴를 재현한다.
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();
    final duringCollapse = tester.getTopLeft(header).dy;

    // 키보드가 곧바로 돌아온다.
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard * 3);
    await tester.pumpAndSettle();
    final restored = tester.getTopLeft(header).dy;

    expect(
      duringCollapse,
      moreOrLessEquals(settled, epsilon: 1.0),
      reason: '포커스를 쥔 동안 인셋이 잠깐 0이 되어도 시트는 제자리여야 한다 '
          '(실측 진폭 334.8만큼 내려갔다 올라오는 것이 신고된 증상)',
    );
    expect(restored, moreOrLessEquals(settled, epsilon: 1.0));
  });

  testWidgets('포커스가 없으면 키보드 자리를 되돌려준다', (tester) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    addTearDown(tester.view.reset);
    const keyboard = 335.0;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => EventEditDialog.show(
                  context,
                  initialDate: DateTime(2026, 8, 3),
                  allowKindChange: false,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final header = find.text('일정 추가');
    final noKeyboard = tester.getTopLeft(header).dy;

    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard * 3);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextFormField).at(0));
    await tester.pumpAndSettle();

    // 사용자가 입력을 마치고 포커스를 놓으면(키보드 내림) 자리는 돌아와야 한다 —
    // 래치가 영구히 걸려 빈 공간이 남으면 안 된다.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(header).dy, moreOrLessEquals(noKeyboard, epsilon: 1.0),
        reason: '포커스가 사라지면 키보드 자리를 붙들고 있으면 안 된다');
  });

  testWidgets('포커스를 쥔 채 키보드만 내려가면(안드로이드 뒤로 키) 자리를 돌려준다',
      (tester) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    addTearDown(tester.view.reset);
    const keyboard = 335.0;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => EventEditDialog.show(
                  context,
                  initialDate: DateTime(2026, 8, 3),
                  allowKindChange: false,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final header = find.text('일정 추가');
    final noKeyboard = tester.getTopLeft(header).dy;

    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard * 3);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextFormField).at(0));
    await tester.pumpAndSettle();

    // 안드로이드 뒤로 키: 키보드만 내려가고 **포커스는 남는다**(실측).
    // 유예 안에는 아직 붙들고 있어야 한다 — 포커스 전환과 구분할 수 없으므로.
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.getTopLeft(header).dy, isNot(moreOrLessEquals(noKeyboard, epsilon: 1.0)),
        reason: '유예 안에는 전환 찰나일 수 있으니 자리를 지켜야 한다');

    // 유예가 지나도 낮으면 진짜로 내려간 것 → 자리를 돌려준다.
    await tester.pump(KeyboardInset.grace);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(header).dy,
      moreOrLessEquals(noKeyboard, epsilon: 1.0),
      reason: '뒤로 키로 키보드만 내렸을 때 버튼 아래 빈 공간이 남으면 안 된다 '
          '(실측 292pt 공백이 신고 없이 생겼던 회귀)',
    );
  });
}
