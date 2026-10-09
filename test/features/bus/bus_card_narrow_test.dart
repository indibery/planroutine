import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/bus/domain/bus_arrival.dart';
import 'package:planroutine/features/bus/domain/bus_card_style.dart';
import 'package:planroutine/features/bus/domain/bus_card_view.dart';
import 'package:planroutine/features/bus/domain/commute_direction.dart';
import 'package:planroutine/features/bus/presentation/widgets/bus_arrival_card.dart';
import 'package:planroutine/features/bus/presentation/widgets/bus_body_axis.dart';

/// 2026-10-09 카드 개편(첫 차 크게·분초·두 줄 라벨)이 **좁은 화면에서도** 넘치지 않는지
/// 실제 Pretendard로 잰다. 기본 테스트 글꼴은 모든 글자가 1em이라 실측보다 1.76배 넓게
/// 잡아(`test/tools/visual_check.dart` 참고) 폭 결론을 뒤집는다.
BusCardView _view() => BusCardView(
  state: BusCardState.ok,
  visible: const [
    BusArrival(routeId: 'A', routeNo: '1006-1', arrSec: 605),
    BusArrival(routeId: 'B', routeNo: '5623', arrSec: 719),
    BusArrival(routeId: 'C', routeNo: '9711', arrSec: 734),
  ],
  hiddenCount: 4,
  fetchedAt: DateTime(2026, 10, 9, 16, 7),
);

Future<void> _pump(WidgetTester tester, double width, BusCardStyle style) {
  tester.view.physicalSize = Size(width * 3, 2000);
  tester.view.devicePixelRatio = 3;
  return tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(fontFamily: 'Pretendard'),
      home: Scaffold(
        body: BusArrivalCard(
          view: _view(),
          style: style,
          direction: CommuteDirection.toHome,
          stopName: '석수체육공원.자동차학원.원태우지사의거지',
          expanded: true,
          onToggleExpanded: () {},
          onFlipDirection: () {},
          onRefresh: () {},
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('Pretendard')
      ..addFont(rootBundle.load('assets/fonts/PretendardVariable.ttf'));
    await loader.load();
  });

  for (final width in [320.0, 390.0]) {
    for (final style in BusCardStyle.values) {
      testWidgets('${width.toInt()}pt · ${style.name} — 넘치지 않는다', (
        tester,
      ) async {
        addTearDown(tester.view.reset);
        await _pump(tester, width, style);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('시간 축 라벨 `5623 12분`이 라벨 박스에 여유를 두고 들어간다', (tester) async {
    // FittedBox가 넘치면 줄여 담지만, 기본 크기에서 줄어들면 글자가 작아 읽기 어렵다.
    // 흔한 4자리 + 두 자리 분은 줄이지 않고 들어가야 한다.
    addTearDown(tester.view.reset);
    await _pump(tester, 390, BusCardStyle.axis);
    final label = find.byKey(BusBodyAxis.labelKeyFor('B'));
    final number = tester.getRect(
      find.descendant(of: label, matching: find.text('5623')),
    );
    final minutes = tester.getRect(
      find.descendant(of: label, matching: find.text('12분')),
    );
    expect(
      minutes.right - number.left,
      lessThanOrEqualTo(BusBodyAxis.labelWidth - BusBodyAxis.labelHeadroom),
    );
    expect(
      tester.getSize(find.text('5623')).height,
      greaterThan(10),
      reason: '줄어들지 않은 11pt 글자다',
    );
  });
}
