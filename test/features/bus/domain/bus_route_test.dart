import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/bus/domain/bus_arrival.dart';
import 'package:planroutine/features/bus/domain/bus_route.dart';

BusRoute _r(String id, String no, [String dest = '금정역']) =>
    BusRoute(routeId: id, routeNo: no, destName: dest);

BusArrival _a(String id, String no, int min) =>
    BusArrival.fromMinutes(routeId: id, routeNo: no, arrMin: min);

BusRouteChoice _find(List<BusRouteChoice> cs, String routeNo) =>
    cs.firstWhere((c) => c.route.routeNo == routeNo);

void main() {
  group('buildRouteChoices — 선택 목록은 경유노선에서 나온다', () {
    // 이 그룹이 지키는 것이 실기기 버그 그 자체다: 군포 장미아파트는 경유노선이
    // 10개인데 그 순간 도착정보가 있는 것은 일부였고, 사용자는 자기 버스를 고를 수
    // 없었다.
    test('도착정보에 없는 노선도 목록에 남는다', () {
      final choices = buildRouteChoices(
        routes: [_r('GGB1', '3030'), _r('GGB2', '9'), _r('GGB3', '6501')],
        arrivals: [_a('GGB1', '3030', 4)],
      );

      expect(choices.map((c) => c.route.routeNo), ['9', '3030', '6501']);
    });

    test('도착정보가 있는 노선만 남은 분이 붙는다 — 없으면 null이다', () {
      final choices = buildRouteChoices(
        routes: [_r('GGB1', '3030'), _r('GGB2', '9')],
        arrivals: [_a('GGB1', '3030', 4)],
      );

      expect(_find(choices, '3030').arrMin, 4);
      // **0이 아니라 null이다.** 0으로 뭉개면 도착 정보가 없는 노선이 `곧 도착`으로
      // 보이고, 심야에 등록하면 목록 전체가 그렇게 된다.
      expect(_find(choices, '9').arrMin, isNull);
    });

    test('0분(곧 도착)과 정보 없음(null)이 구별된다', () {
      final choices = buildRouteChoices(
        routes: [_r('GGB1', '3030'), _r('GGB2', '9')],
        arrivals: [_a('GGB1', '3030', 0)],
      );

      expect(_find(choices, '3030').arrMin, 0);
      expect(_find(choices, '9').arrMin, isNull);
    });

    test('경유노선에 없는 도착정보는 목록을 늘리지 않는다', () {
      // 실측 두 정류장에서 도착 노선 집합 ⊆ 경유 노선 집합이었다. 어긋나도 목록의
      // 기준은 경유노선 하나여야 한다 — 두 소스를 합치면 어느 쪽이 목록인지 모호해진다.
      final choices = buildRouteChoices(
        routes: [_r('GGB1', '3030')],
        arrivals: [_a('GGB1', '3030', 4), _a('GGB9', '999', 1)],
      );

      expect(choices, hasLength(1));
      expect(choices.single.route.routeNo, '3030');
    });

    test('routeId를 그대로 들고 있다 — 이 값이 곧 저장되는 필터다', () {
      final choices = buildRouteChoices(
        routes: [_r('GGB208000027', '3030')],
        arrivals: const [],
      );

      expect(choices.single.routeId, 'GGB208000027');
    });
  });

  group('buildRouteChoices — 경유노선이 없으면 도착정보로 폴백한다', () {
    // 비경기 정류장(부산 `BSB…`·제주 `JEB…`)은 경유노선 API가 없고, 경기 정류장도
    // 그 조회만 실패할 수 있다. 그때 기존(도착정보 기반) 동작으로 정확히 돌아가야 한다.
    test('도착정보로 목록을 만든다', () {
      final choices = buildRouteChoices(
        routes: const [],
        arrivals: [_a('A', '82-1', 2), _a('B', '720', 8)],
      );

      expect(choices.map((c) => c.route.routeNo), ['82-1', '720']);
      expect(_find(choices, '82-1').arrMin, 2);
    });

    test('폴백 항목은 행선지가 비어 있다 — TAGO 도착 응답에 행선지가 없다', () {
      final choices = buildRouteChoices(
        routes: const [],
        arrivals: [_a('A', '82-1', 2)],
      );

      expect(choices.single.route.destName, isEmpty);
    });

    test('둘 다 비면 빈 목록이다', () {
      expect(
        buildRouteChoices(routes: const [], arrivals: const []),
        isEmpty,
      );
    });
  });

  group('compareRouteNo — 자기 번호를 훑어 찾을 수 있어야 한다', () {
    test('장미아파트 실측 10노선이 번호순으로 선다', () {
      final routes = [
        _r('a', '3030'), _r('b', '6501'), _r('c', '11-5'), _r('d', '15'),
        _r('e', '541'), _r('f', '5623'), _r('g', '87'), _r('h', '917'),
        _r('i', '6'), _r('j', '9'),
      ];

      final choices = buildRouteChoices(routes: routes, arrivals: const []);

      // 사전순으로 두면 `11-5`가 `6`보다 앞에 오고 `3030`이 맨 위에 온다.
      expect(
        choices.map((c) => c.route.routeNo),
        ['6', '9', '11-5', '15', '87', '541', '917', '3030', '5623', '6501'],
      );
    });

    test('같은 수로 시작하면 짧은 쪽이 먼저다', () {
      expect(compareRouteNo('11', '11-5'), lessThan(0));
      expect(compareRouteNo('11-5', '11-3'), greaterThan(0));
    });

    test('숫자로 시작하지 않는 노선은 뒤로 모인다', () {
      // 마을버스에 `A`·`가` 같은 번호가 있다. 앞에 두면 숫자 노선을 훑는 흐름이 끊긴다.
      final choices = buildRouteChoices(
        routes: [_r('a', '마을A'), _r('b', '9'), _r('c', '3030')],
        arrivals: const [],
      );

      expect(choices.map((c) => c.route.routeNo), ['9', '3030', '마을A']);
    });

    test('숫자로 시작하지 않는 노선끼리는 사전순이다', () {
      expect(compareRouteNo('마을A', '마을B'), lessThan(0));
    });
  });
}
