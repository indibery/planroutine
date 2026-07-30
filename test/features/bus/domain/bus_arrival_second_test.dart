import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/bus/domain/bus_arrival.dart';
import 'package:planroutine/features/bus/domain/bus_card_view.dart';

void main() {
  group('BusArrival.arrSec2 — 그 다음 차', () {
    test('없을 수 있다 — 모든 노선이 2차를 주지는 않는다', () {
      const a = BusArrival(routeId: 'R', routeNo: '5623', arrSec: 300);
      expect(a.arrSec2, isNull);
    });

    test('분으로도 만들 수 있다', () {
      final a = BusArrival.fromMinutes(
        routeId: 'R',
        routeNo: '5623',
        arrMin: 5,
        arrMin2: 14,
      );
      expect(a.arrSec2, 840);
    });

    test('copyWith가 2차도 갈아끼운다', () {
      const a = BusArrival(
        routeId: 'R',
        routeNo: '5623',
        arrSec: 300,
        arrSec2: 840,
      );
      expect(a.copyWith(arrSec: 200, arrSec2: 740).arrSec2, 740);
      expect(a.copyWith(arrSec: 200).arrSec2, 840, reason: '안 주면 보존한다');
    });
  });

  group('경과 보정은 2차도 함께 깎는다', () {
    test('60초가 지나면 1차도 2차도 60초 줄어든다', () {
      // 안 깎으면 `다음 14분`이 화면에서 멈춰 있는다 — 1차만 흐르고 2차는 얼어붙어
      // 둘의 간격이 시간이 갈수록 벌어진다.
      final at = DateTime(2026, 7, 30, 8);
      final view = buildBusCardView(
        state: BusCardState.ok,
        arrivals: const [
          BusArrival(routeId: 'R', routeNo: '5623', arrSec: 300, arrSec2: 840),
        ],
        fetchedAt: at,
        now: at.add(const Duration(seconds: 60)),
      );

      expect(view.visible.single.arrSec, 240);
      expect(view.visible.single.arrSec2, 780);
    });

    test('2차가 지나가면 0에서 멈춘다', () {
      final at = DateTime(2026, 7, 30, 8);
      final view = buildBusCardView(
        state: BusCardState.ok,
        arrivals: const [
          BusArrival(routeId: 'R', routeNo: '5623', arrSec: 60, arrSec2: 120),
        ],
        fetchedAt: at,
        now: at.add(const Duration(seconds: 300)),
      );

      expect(view.visible.single.arrSec, 0);
      expect(view.visible.single.arrSec2, 0);
    });

    test('2차가 없으면 없는 채로 둔다', () {
      final at = DateTime(2026, 7, 30, 8);
      final view = buildBusCardView(
        state: BusCardState.ok,
        arrivals: const [
          BusArrival(routeId: 'R', routeNo: '5623', arrSec: 300),
        ],
        fetchedAt: at,
        now: at.add(const Duration(seconds: 60)),
      );

      expect(view.visible.single.arrSec2, isNull);
    });
  });
}
