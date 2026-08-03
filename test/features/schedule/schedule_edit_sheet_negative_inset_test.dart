import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:planroutine/features/schedule/domain/schedule.dart';
import 'package:planroutine/features/schedule/presentation/widgets/schedule_edit_sheet.dart';

/// 키보드 여백은 **음수 인셋을 그대로 넘기지 않는다.**
///
/// 실기(3.41.6)에서 한 번 관측했다 — `RenderPadding.padding`의
/// `value.isNonNegative` assert가 터져 앱이 빨간 화면으로 갔고, 그 뒤로
/// `referenceBox.attached`·`Duplicate GlobalKey`·`_dependents.isEmpty`가
/// 연달아 무너졌다. 여백 값의 출처는 `MediaQuery.viewInsetsOf(...).bottom`
/// 하나뿐이므로 **그 순간 플랫폼이 음수를 보고했다**는 결론이 나온다.
///
/// 업스트림에 음수 사례가 문서화돼 있지는 않지만, 빠른 개폐 중 값이 틀리는 계열은
/// 실재한다(flutter/flutter#163502). 원인을 모르는 채 방어를 걷어내지 않는다.
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
                onPressed: () => ScheduleEditSheet.show(
                  context,
                  const Schedule(
                    id: 1,
                    title: '학사일정 협의',
                    scheduledDate: '2026-03-02',
                  ),
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
    expect(find.text('일정 수정'), findsOneWidget, reason: '시트가 살아 있어야 한다');
  });
}
