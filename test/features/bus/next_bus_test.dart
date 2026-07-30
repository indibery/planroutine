import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/bus/domain/bus_arrival.dart';
import 'package:planroutine/features/bus/domain/bus_card_view.dart';
import 'package:planroutine/features/bus/domain/next_bus.dart';
import 'package:planroutine/features/bus/presentation/widgets/bus_body_axis.dart';
import 'package:planroutine/features/bus/presentation/widgets/bus_body_text.dart';

BusCardView _view(List<BusArrival> items) => BusCardView(
      state: BusCardState.ok,
      visible: items,
      hiddenCount: 0,
      fetchedAt: DateTime(2026, 7, 30, 8),
    );

BusArrival _a(String id, int sec, {int? sec2}) =>
    BusArrival(routeId: id, routeNo: id, arrSec: sec, arrSec2: sec2);

Future<void> _pump(WidgetTester tester, Widget body) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: SizedBox(width: 320, child: body)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('nextBusMinutes — 순수 함수', () {
    test('한 대만 보이고 2차가 있으면 분으로 준다', () {
      expect(nextBusMinutes(_view([_a('A', 300, sec2: 840)])), 14);
    });

    test('여러 대가 보이면 붙이지 않는다 — 목록이 이미 대안이다', () {
      expect(
        nextBusMinutes(_view([_a('A', 300, sec2: 840), _a('B', 500)])),
        isNull,
      );
    });

    test('2차가 없으면 붙이지 않는다', () {
      expect(nextBusMinutes(_view([_a('A', 300)])), isNull);
    });

    test('이미 지나간 2차는 붙이지 않는다 — `다음 0분`은 정보가 아니다', () {
      expect(nextBusMinutes(_view([_a('A', 0, sec2: 0)])), isNull);
    });

    test('목록이 비면 붙이지 않는다', () {
      expect(nextBusMinutes(_view([])), isNull);
    });
  });

  group('두 본문 모양이 같은 정보를 그린다', () {
    testWidgets('간단히 — 한 대일 때 다음 차가 보인다', (tester) async {
      await _pump(tester, BusBodyText(view: _view([_a('A', 300, sec2: 840)])));
      expect(find.text(BusStrings.nextBus(14)), findsOneWidget);
    });

    testWidgets('시간 축 — 한 대일 때 다음 차가 보인다', (tester) async {
      await _pump(tester, BusBodyAxis(view: _view([_a('A', 300, sec2: 840)])));
      expect(find.text(BusStrings.nextBus(14)), findsOneWidget);
    });

    testWidgets('간단히 — 여러 대면 안 보인다', (tester) async {
      await _pump(
        tester,
        BusBodyText(view: _view([_a('A', 300, sec2: 840), _a('B', 500)])),
      );
      expect(find.textContaining('다음'), findsNothing);
    });

    testWidgets('시간 축 — 여러 대면 안 보인다', (tester) async {
      await _pump(
        tester,
        BusBodyAxis(view: _view([_a('A', 300, sec2: 840), _a('B', 500)])),
      );
      expect(find.textContaining('다음'), findsNothing);
    });
  });
}
