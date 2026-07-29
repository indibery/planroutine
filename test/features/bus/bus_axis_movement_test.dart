import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/features/bus/domain/bus_arrival.dart';
import 'package:planroutine/features/bus/domain/bus_card_view.dart';
import 'package:planroutine/features/bus/presentation/widgets/bus_body_axis.dart';

const _axisWidth = 300.0;

BusCardView _viewOf(List<BusArrival> items) => BusCardView(
      state: BusCardState.ok,
      visible: items,
      hiddenCount: 0,
      fetchedAt: DateTime(2026, 7, 30, 8, 1),
    );

Future<void> _pump(WidgetTester tester, BusCardView view) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SizedBox(width: _axisWidth, child: BusBodyAxis(view: view)),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('시간 축 — 초 단위 배치', () {
    test('같은 분 안에서도 초가 다르면 자리가 다르다', () {
      // 이 하나가 신고의 핵심이다 — 예전에는 둘 다 `6분`이라 같은 자리에 섰다.
      final a = BusBodyAxis.dotPosition(359);
      final b = BusBodyAxis.dotPosition(361);

      expect(a, isNot(closeTo(b, 0.0001)));
      expect(a, lessThan(b));
    });

    test('1초가 지나면 왼쪽으로 간다', () {
      expect(
        BusBodyAxis.dotPosition(300),
        lessThan(BusBodyAxis.dotPosition(301)),
      );
    });

    test('양 끝 clamp는 그대로다', () {
      expect(BusBodyAxis.dotPosition(0), closeTo(0.03, 0.001));
      expect(BusBodyAxis.dotPosition(99 * 60), closeTo(0.97, 0.001));
    });
  });

  group('시간 축 — 보조 눈금', () {
    testWidgets('1분 간격 눈금이 축 안쪽에만 그려진다', (tester) async {
      // 0분·15분은 라벨이 이미 말하고, 끝에 세우면 레일 마구리와 겹친다.
      await _pump(tester, _viewOf([]));

      final ticks = find.byWidgetPredicate(
        (w) => w is Container && w.constraints?.maxWidth == 1,
      );
      expect(ticks, findsNWidgets(BusBodyAxis.axisRange - 1));
    });
  });

  group('시간 축 — 움직임', () {
    testWidgets('점과 라벨이 이름 있는 키를 들고 있다', (tester) async {
      // `AnimatedPositioned`가 프레임 사이에 같은 점을 잇는 근거다. 키가 없으면
      // Flutter가 Stack 자식을 순서로 매칭해, 정렬이 바뀔 때 A의 점이 B 자리로
      // 미끄러진다(색까지 함께 건너간다).
      await _pump(tester, _viewOf([
        BusArrival(routeId: 'R1', routeNo: '5623', arrSec: 359),
        BusArrival(routeId: 'R2', routeNo: '541', arrSec: 620),
      ]));

      expect(find.byKey(BusBodyAxis.dotKey('R1')), findsOneWidget);
      expect(find.byKey(BusBodyAxis.dotKey('R2')), findsOneWidget);
      expect(find.byKey(BusBodyAxis.labelKey('R1')), findsOneWidget);
      expect(find.byKey(BusBodyAxis.labelKey('R2')), findsOneWidget);
    });

    testWidgets('초가 줄면 점이 실제로 왼쪽으로 이동한다', (tester) async {
      await _pump(tester, _viewOf([
        BusArrival(routeId: 'R1', routeNo: '5623', arrSec: 600),
      ]));
      final before = tester.getRect(find.byKey(BusBodyAxis.dotKey('R1'))).center.dx;

      await _pump(tester, _viewOf([
        BusArrival(routeId: 'R1', routeNo: '5623', arrSec: 540),
      ]));
      final after = tester.getRect(find.byKey(BusBodyAxis.dotKey('R1'))).center.dx;

      expect(after, lessThan(before));
    });
  });

  group('경과 보정 — 초 단위', () {
    test('30초가 지나면 분은 그대로여도 초가 줄어든다', () {
      final fetchedAt = DateTime(2026, 7, 30, 8, 0, 0);
      final view = buildBusCardView(
        state: BusCardState.ok,
        arrivals: [BusArrival(routeId: 'R1', routeNo: '5623', arrSec: 361)],
        fetchedAt: fetchedAt,
        now: fetchedAt.add(const Duration(seconds: 30)),
      );

      expect(view.visible.single.arrSec, 331);
      // 331초 = 5.52분 → 반올림 6분. 표시는 안 바뀌고 점만 움직인다.
      expect(view.visible.single.arrMin, 6);
    });

    test('남은 시간을 넘겨 지나면 0으로 바닥을 친다', () {
      final fetchedAt = DateTime(2026, 7, 30, 8, 0, 0);
      final view = buildBusCardView(
        state: BusCardState.ok,
        arrivals: [BusArrival(routeId: 'R1', routeNo: '5623', arrSec: 40)],
        fetchedAt: fetchedAt,
        now: fetchedAt.add(const Duration(seconds: 90)),
      );

      expect(view.visible.single.arrSec, 0);
      expect(view.visible.single.arrMin, 0);
    });
  });
}
