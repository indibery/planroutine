import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/bus/domain/bus_stop.dart';
import 'package:planroutine/features/bus/domain/stop_search_view.dart';

BusStop _stop(String name, String? region, {int no = 1}) => BusStop(
      nodeId: 'GGB$no',
      nodeNm: name,
      nodeNo: no,
      cityCode: 0,
      regionName: region,
    );

List<BusStop> _many(String region, int n) =>
    List.generate(n, (i) => _stop('정류장$i', region, no: i + 1));

void main() {
  group('buildStopSearchView — 이름 검색 결과가 감당이 안 된다', () {
    // 실측: `시청` 160곳, **`아파트` 4,366곳**. 상한이 없으면 4천 개 위젯을 만들고
    // 사용자는 그 안에서 자기 정류장을 찾지 못한다.
    test('상한까지만 그린다', () {
      final view = buildStopSearchView(stops: _many('을시', 200));

      expect(view.visible, hasLength(stopSearchRenderCap));
      expect(view.total, 200);
      expect(view.truncated, isTrue);
    });

    test('상한 안이면 잘리지 않는다', () {
      final view = buildStopSearchView(stops: _many('을시', 10));

      expect(view.visible, hasLength(10));
      expect(view.truncated, isFalse);
    });

    test('지역을 고르면 그 지역만 남고 상한도 다시 계산된다', () {
      final view = buildStopSearchView(
        stops: [..._many('을시', 60), ..._many('갑시', 3)],
        region: '갑시',
      );

      expect(view.visible, hasLength(3));
      expect(view.total, 3, reason: 'total은 필터 뒤 건수다 — 안내 문구가 이 수를 쓴다');
      expect(view.truncated, isFalse);
    });
  });

  group('지역 칩 — 결과를 세어 만든다 (추가 조회 없음)', () {
    test('건수 내림차순이다 — 많은 쪽이 내 정류장을 담고 있을 확률이 높다', () {
      final view = buildStopSearchView(stops: [
        ..._many('인천', 5),
        ..._many('갑시', 1),
        ..._many('병시', 2),
      ]);

      expect(view.regions.map((r) => r.name), ['인천', '병시', '갑시']);
      expect(view.regions.first.count, 5);
    });

    test('건수가 같으면 이름순 — 같은 결과에서 칩 순서가 흔들리지 않게', () {
      final view = buildStopSearchView(stops: [
        ..._many('정시', 2),
        ..._many('병시', 2),
      ]);

      expect(view.regions.map((r) => r.name), ['병시', '정시']);
    });

    test('칩에도 상한이 있다 — 33종이 나오는 경우가 있다', () {
      final stops = <BusStop>[];
      for (var i = 0; i < 20; i++) {
        stops.addAll(_many('지역$i', 1));
      }
      final view = buildStopSearchView(stops: stops);

      expect(view.regions, hasLength(stopSearchRegionChipCap));
    });

    test('지역이 한 종류면 고를 것이 없다', () {
      final view = buildStopSearchView(stops: _many('을시', 10));

      expect(view.hasRegionChoice, isFalse);
    });

    test('두 종류 이상이면 칩을 보여줄 만하다', () {
      final view = buildStopSearchView(
        stops: [..._many('을시', 1), ..._many('갑시', 1)],
      );

      expect(view.hasRegionChoice, isTrue);
    });

    test('지역을 골라도 칩의 건수는 그대로다 — 되돌아갈 수 있어야 한다', () {
      // 필터를 반영하면 한 지역을 고른 순간 다른 칩이 0이 되거나 사라져 되돌릴 수 없다.
      final all = [..._many('인천', 5), ..._many('갑시', 1)];

      final filtered = buildStopSearchView(stops: all, region: '갑시');

      expect(filtered.regions.map((r) => (r.name, r.count)),
          [('인천', 5), ('갑시', 1)]);
    });

    test('지역명이 없는 결과(TAGO 경로)는 칩을 만들지 않는다', () {
      // 그 경로는 이미 도시를 골랐다 — 칩을 또 주면 같은 선택을 두 번 하게 된다.
      final view = buildStopSearchView(
        stops: [_stop('서면', null), _stop('서면2', null, no: 2)],
      );

      expect(view.regions, isEmpty);
      expect(view.hasRegionChoice, isFalse);
      expect(view.visible, hasLength(2), reason: '칩이 없어도 목록은 그린다');
    });

    test('빈 결과는 빈 뷰다', () {
      final view = buildStopSearchView(stops: const []);

      expect(view.visible, isEmpty);
      expect(view.regions, isEmpty);
      expect(view.total, 0);
      expect(view.truncated, isFalse);
    });
  });
}
