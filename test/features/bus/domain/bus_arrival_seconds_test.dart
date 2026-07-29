import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/bus/domain/bus_arrival.dart';

BusArrival _sec(int arrSec) =>
    BusArrival(routeId: 'A', routeNo: '5623', arrSec: arrSec);

void main() {
  group('BusArrival — 초가 진실의 원천', () {
    test('arrMin은 초에서 반올림해 파생된다', () {
      expect(_sec(361).arrMin, 6); // 6분 1초
      expect(_sec(359).arrMin, 6); // 5분 59초 → 같은 분, 다른 초
      expect(_sec(330).arrMin, 6); // 5분 30초 (경계, round)
      expect(_sec(329).arrMin, 5);
    });

    test('1분 미만이 0으로 뭉개지지 않는다', () {
      // 59초는 "곧 도착"이 아니라 1분이다 — 0으로 읽으면 이미 지나간 것처럼 보인다.
      expect(_sec(59).arrMin, 1);
      expect(_sec(30).arrMin, 1); // 0.5 → round는 1
      expect(_sec(20).arrMin, 0);
      expect(_sec(0).arrMin, 0);
    });

    test('fromMinutes는 분을 초로 환산한다', () {
      // 분만 아는 경로(GBIS predictTime1 폴백)와 테스트 픽스처가 쓴다.
      final a = BusArrival.fromMinutes(routeId: 'A', routeNo: '9', arrMin: 7);
      expect(a.arrSec, 420);
      expect(a.arrMin, 7);
    });

    test('copyWith는 초만 갈아끼우고 나머지를 보존한다', () {
      final a = BusArrival(
        routeId: 'A',
        routeNo: '5623',
        arrSec: 361,
        lowFloor: true,
      );
      final b = a.copyWith(arrSec: 331);

      expect(b.arrSec, 331);
      expect(b.routeId, 'A');
      expect(b.routeNo, '5623');
      expect(b.lowFloor, isTrue);
    });
  });
}
