import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/bus/domain/bus_settings.dart';
import 'package:planroutine/features/bus/domain/bus_settings_summary.dart';
import 'package:planroutine/features/bus/domain/bus_stop.dart';

BusStop _stop(String name) => BusStop(
  nodeId: 'GGB$name',
  nodeNm: name,
  nodeNo: 26044,
  cityCode: 0,
  regionName: '군포',
);

void main() {
  group('buildBusSettingsSummary — 켜진 행의 부제', () {
    test('정류장이 없으면 등록하라고 말한다', () {
      // 처음 켠 사람에게 다음 행동을 알린다 — 화면을 옮기지 않으므로 이 한 줄이 안내다.
      expect(
        buildBusSettingsSummary(BusSettings.defaults),
        BusStrings.summaryNoStop,
      );
    });

    test('요약은 켜짐·꺼짐을 말하지 않는다 — 그건 스위치가 말한다', () {
      // 요약은 켜진 행에만 쓰인다. `켜짐 · 2곳`처럼 상태를 다시 적으면 바로 옆
      // 스위치와 같은 말을 두 번 한다.
      final both = BusSettings.defaults.copyWith(
        departure: _stop('우방아파트'),
        arrival: _stop('중앙공원'),
      );
      for (final s in [BusSettings.defaults, both]) {
        final text = buildBusSettingsSummary(s);
        expect(text, isNot(contains('켜짐')));
        expect(text, isNot(contains('꺼짐')));
      }
    });

    test('한 곳만 등록하면 1곳', () {
      final settings = BusSettings.defaults.copyWith(
        departure: _stop('우방아파트'),
      );
      expect(buildBusSettingsSummary(settings), BusStrings.summaryStops(1));
    });

    test('두 곳을 등록하면 2곳', () {
      final settings = BusSettings.defaults.copyWith(
        departure: _stop('우방아파트'),
        arrival: _stop('중앙공원'),
      );
      expect(buildBusSettingsSummary(settings), BusStrings.summaryStops(2));
    });

    test('도착지만 등록해도 1곳이다', () {
      final settings = BusSettings.defaults.copyWith(
        arrival: _stop('중앙공원'),
      );
      expect(buildBusSettingsSummary(settings), BusStrings.summaryStops(1));
    });
  });
}
