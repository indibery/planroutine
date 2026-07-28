import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/bus/domain/bus_arrival.dart';
import 'package:planroutine/features/bus/domain/bus_card_view.dart';

DateTime _at(int hour, int minute, [int second = 0]) =>
    DateTime(2026, 7, 28, hour, minute, second);

BusArrival _a(String routeId, String routeNo, int arrMin) =>
    BusArrival(routeId: routeId, routeNo: routeNo, arrMin: arrMin);

BusCardView _build({
  required List<BusArrival> arrivals,
  DateTime? fetchedAt,
  DateTime? now,
  Set<String> routeIds = const {},
  BusCardState state = BusCardState.ok,
}) {
  return buildBusCardView(
    state: state,
    arrivals: arrivals,
    fetchedAt: fetchedAt ?? _at(7, 32),
    now: now ?? _at(7, 32),
    routeIds: routeIds,
  );
}

void main() {
  group('경과 보정 — 캐시가 묵은 만큼 차감한다', () {
    test('50초 지나면 4분이 3분으로 나간다', () {
      final v = _build(
        arrivals: [_a('A', '720', 4)],
        fetchedAt: _at(7, 32, 0),
        now: _at(7, 32, 50),
      );
      expect(v.visible.single.arrMin, 3);
    });

    test('보정으로 0분 아래가 되면 0분(곧 도착)에서 멈춘다', () {
      final v = _build(
        arrivals: [_a('A', '720', 1)],
        fetchedAt: _at(7, 32, 0),
        now: _at(7, 35, 0),
      );
      expect(v.visible.single.arrMin, 0);
    });

    test('fetchedAt이 없으면 보정하지 않는다', () {
      final v = _build(arrivals: [_a('A', '720', 4)], fetchedAt: null);
      expect(v.visible.single.arrMin, 4);
    });
  });

  group('노선 필터', () {
    test('routeIds가 비면 전부 통과한다 — 필터 없음을 뜻한다', () {
      final v = _build(arrivals: [_a('A', '1', 2), _a('B', '2', 5)]);
      expect(v.visible.length, 2);
    });

    test('골라두면 그것만 통과한다', () {
      final v = _build(
        arrivals: [_a('A', '1', 2), _a('B', '2', 5), _a('C', '3', 8)],
        routeIds: {'A', 'C'},
      );
      expect(v.visible.map((e) => e.routeNo).toList(), ['1', '3']);
    });

    test('골라둔 노선이 지금 안 오면 운행 종료로 읽힌다', () {
      final v = _build(arrivals: [_a('A', '1', 2)], routeIds: {'Z'});
      expect(v.state, BusCardState.closed);
      expect(v.visible, isEmpty);
    });
  });

  group('표시 상한 — 필터를 걸었는지에 따라 다르다', () {
    final five = [
      _a('R1', '82-1', 8), _a('R2', '92', 10), _a('R3', '92-1', 10),
      _a('R4', '81', 13), _a('R5', '61', 31),
    ];

    test('필터 없으면 3개만 보이고 남은 수를 센다', () {
      final v = _build(arrivals: five);
      expect(v.visible.length, 3);
      expect(v.hiddenCount, 2);
    });

    test('골라두면 5개도 전부 보인다 — 자기가 고른 것을 자르지 않는다', () {
      final v = _build(arrivals: five, routeIds: {'R1','R2','R3','R4','R5'});
      expect(v.visible.length, 5);
      expect(v.hiddenCount, 0);
    });

    test('보정된 값 기준으로 상한을 자른다', () {
      // 조회 시점엔 A(2) B(3) C(4) D(5)였고 보정 뒤에도 순서는 같다(A가 0분이 됨).
      // 이 테스트는 정렬이 아니라 "상한이 보정된 값을 본다"만 검증한다 — 입력이
      // 이미 오름차순이라 sort를 지워도 결과가 같다(정렬 자체는 아래
      // '정렬되지 않은 입력을 빠른 순으로 정렬한다'가 검증한다).
      final v = _build(
        arrivals: [_a('A','1',2), _a('B','2',3), _a('C','3',4), _a('D','4',5)],
        fetchedAt: _at(7, 32, 0),
        now: _at(7, 34, 0),
      );
      expect(v.visible.map((e) => e.routeNo).toList(), ['1', '2', '3']);
      expect(v.visible.first.arrMin, 0);
    });

    test('정렬되지 않은 입력을 빠른 순으로 정렬한다', () {
      // 이 테스트가 없으면 buildBusCardView의 sort를 지워도 아무 테스트가 깨지지 않는다.
      // 다른 픽스처는 모두 이미 오름차순 입력이라 sort를 통과시켜도 결과가 같다.
      final v = _build(arrivals: [_a('A', '10번', 10), _a('B', '2번', 2), _a('C', '5번', 5)]);
      expect(v.visible.map((e) => e.routeNo).toList(), ['2번', '5번', '10번']);
    });
  });

  group('임박 판정', () {
    test('3분 미만은 임박, 3분은 임박이 아니다', () {
      expect(isUrgent(2), isTrue);
      expect(isUrgent(0), isTrue);
      expect(isUrgent(3), isFalse);
    });

    test('3~7분은 soon, 8분은 아니다', () {
      expect(isSoon(3), isTrue);
      expect(isSoon(7), isTrue);
      expect(isSoon(8), isFalse);
      expect(isSoon(2), isFalse);
    });
  });

  group('상태 전달', () {
    test('빈 목록이면 closed로 바뀐다', () {
      final v = _build(arrivals: const []);
      expect(v.state, BusCardState.closed);
    });

    test('down은 목록이 없어도 그대로 유지된다 — 막차와 구별해야 한다', () {
      final v = _build(arrivals: const [], state: BusCardState.down);
      expect(v.state, BusCardState.down);
    });

    test('stale은 목록을 유지한다', () {
      final v = _build(arrivals: [_a('A', '1', 4)], state: BusCardState.stale);
      expect(v.state, BusCardState.stale);
      expect(v.hasRows, isTrue);
    });
  });
}
