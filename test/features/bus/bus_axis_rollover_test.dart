import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/features/bus/domain/bus_arrival.dart';
import 'package:planroutine/features/bus/domain/bus_card_view.dart';
import 'package:planroutine/features/bus/presentation/widgets/bus_body_axis.dart';

const _axisWidth = 300.0;

BusCardView _view(BusArrival a) => BusCardView(
  state: BusCardState.ok,
  visible: [a],
  hiddenCount: 0,
  fetchedAt: DateTime(2026, 7, 30, 8),
);

Future<void> _pump(WidgetTester tester, BusArrival a) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: _axisWidth,
          child: BusBodyAxis(view: _view(a)),
        ),
      ),
    ),
  );
}

void main() {
  group('앞차가 지나가도 점이 뒤로 가지 않는다', () {
    // **실기기 신고 2026-07-30**: 앞차가 도착하면 점들이 오른쪽으로(= 시간을
    // 거슬러) 미끄러졌다. 키가 `routeId`라 같은 노선의 다음 차가 1차가 되는 순간
    // `AnimatedPositioned`가 같은 위젯의 위치만 0분 → 8분으로 옮긴 탓이다.
    //
    // 사용자가 기대한 것: **2차가 그 자리에서 1차가 되고, 새 차가 뒤에 생긴다.**

    testWidgets('2차였던 차량이 1차가 되면 제자리에 남는다', (tester) async {
      // 앞차 B는 곧 도착, 뒤차 C는 8분 뒤.
      await _pump(
        tester,
        const BusArrival(
          routeId: 'R',
          routeNo: '5623',
          arrSec: 20,
          arrSec2: 480,
          vehicleId: 'B',
          vehicleId2: 'C',
        ),
      );
      await tester.pumpAndSettle();

      final before = tester.getRect(find.byKey(BusBodyAxis.dotKeyFor('C')));

      // 다음 조회 — B는 지나갔고 C가 1차가 됐다. 그 뒤로 D가 새로 잡혔다.
      await _pump(
        tester,
        const BusArrival(
          routeId: 'R',
          routeNo: '5623',
          arrSec: 470,
          arrSec2: 1100,
          vehicleId: 'C',
          vehicleId2: 'D',
        ),
      );
      await tester.pumpAndSettle();

      final after = tester.getRect(find.byKey(BusBodyAxis.dotKeyFor('C')));

      expect(
        (after.center.dx - before.center.dx).abs(),
        lessThan(5),
        reason: 'C는 같은 차량이다 — 1차가 됐다고 자리를 옮기면 안 된다',
      );
    });

    testWidgets('지나간 차량의 점은 사라진다', (tester) async {
      await _pump(
        tester,
        const BusArrival(
          routeId: 'R',
          routeNo: '5623',
          arrSec: 20,
          arrSec2: 480,
          vehicleId: 'B',
          vehicleId2: 'C',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(BusBodyAxis.dotKeyFor('B')), findsOneWidget);

      await _pump(
        tester,
        const BusArrival(
          routeId: 'R',
          routeNo: '5623',
          arrSec: 470,
          arrSec2: 1100,
          vehicleId: 'C',
          vehicleId2: 'D',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(BusBodyAxis.dotKeyFor('B')), findsNothing);
    });

    testWidgets('새 뒤차는 오른쪽에 생긴다', (tester) async {
      await _pump(
        tester,
        const BusArrival(
          routeId: 'R',
          routeNo: '5623',
          arrSec: 470,
          arrSec2: 800,
          vehicleId: 'C',
          vehicleId2: 'D',
        ),
      );
      await tester.pumpAndSettle();

      final first = tester.getRect(find.byKey(BusBodyAxis.dotKeyFor('C')));
      final next = tester.getRect(find.byKey(BusBodyAxis.dotKeyFor('D')));
      expect(next.center.dx, greaterThan(first.center.dx));
    });

    testWidgets('차량 식별자가 없으면 노선으로 떨어진다 — TAGO 경로', (tester) async {
      // TAGO 응답에는 차량 ID가 없다. 그때도 점은 그려져야 한다(뒤로 가는 문제는
      // 그 경로에 남는다 — 수도권은 GBIS라 주 경로는 고쳐진다).
      await _pump(
        tester,
        const BusArrival(routeId: 'R', routeNo: '5623', arrSec: 300),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(BusBodyAxis.dotKeyFor('R')), findsOneWidget);
    });
  });
}
