import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/bus/domain/bus_card_style.dart';
import 'package:planroutine/features/bus/domain/bus_settings.dart';
import 'package:planroutine/features/bus/domain/bus_stop.dart';
import 'package:planroutine/features/bus/domain/commute_direction.dart';
import 'package:planroutine/features/bus/domain/time_range.dart';

const _stop = BusStop(
  nodeId: 'GGB201000156',
  nodeNm: '수원시청',
  nodeNo: 2251,
  cityCode: 31010,
);

void main() {
  group('기본값 — 조용한 쪽이 기본이다', () {
    test('표시는 꺼져 있고 모양은 간단히다', () {
      expect(BusSettings.defaults.enabled, isFalse);
      expect(BusSettings.defaults.style, BusCardStyle.text);
    });

    test('시간대 기본값은 교사 일과 기준이고 겹치지 않는다', () {
      expect(BusSettings.defaults.toWorkRange.label, '07:00 – 08:30');
      expect(BusSettings.defaults.toHomeRange.label, '16:00 – 18:00');
      expect(BusSettings.defaults.rangesValid, isTrue);
    });
  });

  group('stopFor', () {
    test('방향에 맞는 슬롯을 준다', () {
      final s = BusSettings.defaults.copyWith(departure: _stop);
      expect(s.stopFor(CommuteDirection.toWork)?.nodeId, 'GGB201000156');
      expect(s.stopFor(CommuteDirection.toHome), isNull);
    });
  });

  group('rangesValid', () {
    test('겹치면 무효다', () {
      final s = BusSettings.defaults
          .copyWith(toHomeRange: const TimeRange.hm(8, 0, 18, 0));
      expect(s.rangesValid, isFalse);
    });

    test('뒤집히면 무효다', () {
      final s = BusSettings.defaults
          .copyWith(toWorkRange: const TimeRange.hm(9, 0, 7, 0));
      expect(s.rangesValid, isFalse);
    });
  });

  group('직렬화', () {
    test('전부 채운 값이 왕복한다', () {
      final s = BusSettings.defaults.copyWith(
        enabled: true,
        departure: _stop.copyWith(routeIds: {'A'}),
        arrival: _stop,
        style: BusCardStyle.axis,
        overrideAt: DateTime(2026, 7, 28, 8, 35),
        overrideExpanded: true,
      );
      final back = BusSettings.fromJson(s.toJson());
      expect(back.enabled, isTrue);
      expect(back.departure?.routeIds, {'A'});
      expect(back.style, BusCardStyle.axis);
      expect(back.overrideAt, DateTime(2026, 7, 28, 8, 35));
      expect(back.overrideExpanded, isTrue);
    });

    test('빈 맵이면 기본값으로 읽힌다', () {
      final back = BusSettings.fromJson(const {});
      expect(back.enabled, isFalse);
      expect(back.style, BusCardStyle.text);
      expect(back.departure, isNull);
      expect(back.toWorkRange.label, '07:00 – 08:30');
    });

    test('모르는 모양 이름이면 기본 모양으로 폴백한다', () {
      final back = BusSettings.fromJson(const {'style': 'hologram'});
      expect(back.style, BusCardStyle.text);
    });

    test('clearOverride는 두 값을 함께 지운다', () {
      final s = BusSettings.defaults.copyWith(
        overrideAt: DateTime(2026, 7, 28, 8, 35),
        overrideExpanded: true,
      );
      final cleared = s.clearOverride();
      expect(cleared.overrideAt, isNull);
      expect(cleared.overrideExpanded, isFalse);
    });
  });
}
