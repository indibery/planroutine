import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:planroutine/features/calendar/presentation/widgets/event_edit_dialog.dart';

/// 키보드 여백은 **음수 인셋을 그대로 넘기지 않는다.**
///
/// 실기(3.41.6)에서 한 번 관측했다 — `RenderPadding.padding`의
/// `value.isNonNegative` assert가 터지고 앱이 빨간 화면으로 갔다. 여백 값의 출처는
/// `MediaQuery.viewInsetsOf(...).bottom` 하나뿐이므로 **그 순간 플랫폼이 음수를
/// 보고했다**는 결론이 나온다. 왜 음수를 주는지는 모른다 — 업스트림에 음수 사례가
/// 문서화돼 있지 않고(빠른 개폐 중 값이 틀리는 계열은 실재: flutter/flutter#163502),
/// 그래서 원인 대신 **증상을 막는다.**
///
/// 이 가드는 `KeyboardInset`(3.41.x 깜빡임 workaround)을 걷어낼 때 그 자리를 잇는다.
/// 깜빡임 자체는 3.44.8에서 엔진이 고쳤다(flutter/flutter#182661).
void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR', null);
  });

  testWidgets('음수 인셋이 들어와도 패딩이 0으로 클램프된다', (tester) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    addTearDown(tester.view.reset);

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

    tester.view.viewInsets = const FakeViewPadding(bottom: -100 * 3);
    await tester.pump();

    expect(
      tester.takeException(),
      isNull,
      reason: '음수 인셋을 Padding에 그대로 넘기면 isNonNegative assert가 터진다',
    );
    expect(find.text('일정 추가'), findsOneWidget, reason: '시트가 살아 있어야 한다');
  });
}
