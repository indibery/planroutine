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
  group('buildBusSettingsSummary', () {
    test('꺼져 있으면 꺼짐', () {
      expect(
        buildBusSettingsSummary(BusSettings.defaults),
        BusStrings.summaryOff,
      );
    });

    test('켜져 있고 정류장이 없으면 그 사실을 말한다', () {
      expect(
        buildBusSettingsSummary(BusSettings.defaults.copyWith(enabled: true)),
        BusStrings.summaryNoStop,
      );
    });

    test('한 곳만 등록하면 1곳', () {
      final settings = BusSettings.defaults.copyWith(
        enabled: true,
        departure: _stop('우방아파트'),
      );
      expect(buildBusSettingsSummary(settings), BusStrings.summaryStops(1));
    });

    test('두 곳을 등록하면 2곳', () {
      final settings = BusSettings.defaults.copyWith(
        enabled: true,
        departure: _stop('우방아파트'),
        arrival: _stop('중앙공원'),
      );
      expect(buildBusSettingsSummary(settings), BusStrings.summaryStops(2));
    });

    test('꺼져 있으면 정류장이 있어도 꺼짐이다', () {
      // 켜짐 여부가 먼저다 — 정류장이 남아 있다고 켜진 것처럼 보이면 안 된다.
      final settings = BusSettings.defaults.copyWith(
        departure: _stop('우방아파트'),
        arrival: _stop('중앙공원'),
      );
      expect(buildBusSettingsSummary(settings), BusStrings.summaryOff);
    });
  });
}
