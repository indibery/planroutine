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

  group('축 안/밖 판정 — 점과 글자는 배타적이다', () {
    test('15분 이내면 점으로 그린다', () {
      expect(nextBusOnAxis(_view([_a('A', 120, sec2: 840)])), 840);
      expect(nextBusOffAxis(_view([_a('A', 120, sec2: 840)])), isNull);
    });

    test('정확히 15분은 아직 축 안이다', () {
      expect(nextBusOnAxis(_view([_a('A', 120, sec2: 900)])), 900);
    });

    test('15분을 넘으면 글자로 말한다', () {
      // 점으로 찍으면 dotPosition이 오른쪽 끝으로 clamp해 20분과 40분이 같은
      // 자리에 서고, 실제로 오는 15분 근처 차와도 구별되지 않는다.
      expect(nextBusOnAxis(_view([_a('A', 120, sec2: 1200)])), isNull);
      expect(nextBusOffAxis(_view([_a('A', 120, sec2: 1200)])), 20);
    });

    test('둘이 동시에 값을 주는 경우는 없다', () {
      for (final sec2 in [1, 300, 899, 900, 901, 1800, 5400]) {
        final v = _view([_a('A', 120, sec2: sec2)]);
        final both = nextBusOnAxis(v) != null && nextBusOffAxis(v) != null;
        expect(both, isFalse, reason: 'sec2=$sec2 에서 점과 글자가 겹친다');
      }
    });
  });

  group('두 본문 모양이 같은 정보를 그린다', () {
    testWidgets('간단히 — 한 대일 때 다음 차가 보인다', (tester) async {
      await _pump(tester, BusBodyText(view: _view([_a('A', 300, sec2: 840)])));
      expect(find.text(BusStrings.nextBus(14)), findsOneWidget);
    });

    testWidgets('시간 축 — 15분 이내면 속 빈 점과 다음 라벨이 뜬다', (tester) async {
      await _pump(tester, BusBodyAxis(view: _view([_a('A', 300, sec2: 840)])));

      expect(find.byKey(BusBodyAxis.nextDotKey), findsOneWidget);
      expect(find.byKey(BusBodyAxis.nextLabelKey), findsOneWidget);
      expect(find.text(BusStrings.nextBusShort), findsOneWidget);
      expect(find.text(BusStrings.nextBus(14)), findsNothing,
          reason: '점이 위치로 말하므로 글자 줄은 뜨지 않는다');
    });

    testWidgets('시간 축 — 다음 점은 1차보다 오른쪽에 선다', (tester) async {
      await _pump(tester, BusBodyAxis(view: _view([_a('A', 300, sec2: 840)])));

      final first =
          tester.getRect(find.byKey(BusBodyAxis.dotKey('A'))).center.dx;
      final next = tester.getRect(find.byKey(BusBodyAxis.nextDotKey)).center.dx;
      expect(next, greaterThan(first));
    });

    testWidgets('시간 축 — 15분을 넘으면 점 대신 글자로 말한다', (tester) async {
      await _pump(tester, BusBodyAxis(view: _view([_a('A', 300, sec2: 1500)])));

      expect(find.byKey(BusBodyAxis.nextDotKey), findsNothing);
      expect(find.text(BusStrings.nextBus(25)), findsOneWidget);
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
