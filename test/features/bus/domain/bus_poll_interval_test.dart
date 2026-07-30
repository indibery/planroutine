import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/bus/data/bus_api_client.dart'
    show busMaxDisplayAge;
import 'package:planroutine/features/bus/domain/bus_arrival.dart';
import 'package:planroutine/features/bus/domain/bus_card_view.dart';
import 'package:planroutine/features/bus/domain/bus_poll_interval.dart';

BusCardView _view(List<int> secs, {BusCardState state = BusCardState.ok}) =>
    BusCardView(
      state: state,
      visible: [
        for (var i = 0; i < secs.length; i++)
          BusArrival(routeId: 'R$i', routeNo: '$i', arrSec: secs[i]),
      ],
      hiddenCount: 0,
      fetchedAt: DateTime(2026, 7, 30, 8),
    );

void main() {
  group('busPollIntervalFor', () {
    test('목록이 비면 이유를 가리지 않고 가장 성기게 계속 본다', () {
      // **`closed`에서 멈추는 분기를 두지 않는다.** GBIS가 순간 빈 응답을 주면
      // `BusApiClient`가 그것도 `closed`로 매핑해 막차와 구별되지 않는다 — 멈추면
      // 카드가 수동 새로고침 전까지 영구히 얼어붙는다. 이 앱의 사용층은 출퇴근
      // 시간대라 막차를 거의 만나지 않아, 멈춰서 얻는 것도 없다.
      for (final state in [
        BusCardState.closed,
        BusCardState.down,
        BusCardState.stale,
        BusCardState.keyError,
        BusCardState.filteredOut,
      ]) {
        expect(
          busPollIntervalFor(_view([], state: state)),
          busPollMax,
          reason: '$state 에서 조회가 멈추면 스스로 회복할 수 없다',
        );
      }
    });

    test('먼 버스는 상한 300초', () {
      expect(busPollIntervalFor(_view([600])), const Duration(seconds: 300));
      expect(busPollIntervalFor(_view([1800])), const Duration(seconds: 300));
    });

    test('가까운 버스는 1차 + 30초 — 지나간 직후를 겨냥한다', () {
      expect(busPollIntervalFor(_view([90])), const Duration(seconds: 120));
      expect(busPollIntervalFor(_view([150])), const Duration(seconds: 180));
    });

    test('곧 도착이면 30초 뒤 다시 본다', () {
      // 0초에서 멈춘 카운트다운을 계속 띄우지 않기 위한 최소 재확인.
      expect(busPollIntervalFor(_view([0])), const Duration(seconds: 30));
    });

    test('두 힘이 교차하는 지점은 4분 30초다', () {
      // min(300, first+30)이므로 first=270에서 두 값이 같아진다.
      expect(busPollIntervalFor(_view([269])), const Duration(seconds: 299));
      expect(busPollIntervalFor(_view([270])), const Duration(seconds: 300));
      expect(busPollIntervalFor(_view([271])), const Duration(seconds: 300));
    });

    test('기준은 가장 빠른 버스 하나다 — 뒤에 뭐가 있든', () {
      // `visible`은 buildBusCardView가 이미 정렬해 준다. 목록이 낡는 순간은
      // **맨 앞 버스가 지나갈 때**이므로 그것만 본다.
      final one = busPollIntervalFor(_view([120]));
      final many = busPollIntervalFor(_view([120, 200, 900]));
      expect(many, one);
    });

    test('최장 간격이 busMaxDisplayAge보다 짧다', () {
      // 이 부등식이 깨지면 먼 버스 구간에서 목록이 사라졌다 돌아오며 깜빡인다.
      // 두 상수를 각자 고치다 어긋나는 것을 막는 가드다.
      expect(busPollMax, lessThan(busMaxDisplayAge));
    });
  });
}
