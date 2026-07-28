import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/bus/domain/bus_display.dart';
import 'package:planroutine/features/bus/domain/bus_settings.dart';
import 'package:planroutine/features/bus/domain/commute_direction.dart';

DateTime _at(int hour, int minute) => DateTime(2026, 7, 28, hour, minute);

/// 기본 시간대: 출근 07:00–08:30 / 퇴근 16:00–18:00.
const _s = BusSettings.defaults;

BusDisplay _resolve(DateTime now, {BusSettings settings = _s}) =>
    resolveBusDisplay(now: now, settings: settings);

void main() {
  group('시간대 안 — 펼침 + 그 시간대의 방향', () {
    test('출근 시간대 정각에 열린다', () {
      final d = _resolve(_at(7, 0));
      expect(d.direction, CommuteDirection.toWork);
      expect(d.expanded, isTrue);
    });

    test('출근 시간대 종료 정각까지 펼쳐져 있다', () {
      expect(_resolve(_at(8, 30)).expanded, isTrue);
    });

    test('퇴근 시간대 안이면 퇴근 방향이다', () {
      final d = _resolve(_at(16, 30));
      expect(d.direction, CommuteDirection.toHome);
      expect(d.expanded, isTrue);
    });
  });

  group('시간대 밖 — 접힘 + 다음에 올 시간대의 방향', () {
    test('출근 시간대 1분 전은 접혀 있고 출근을 가리킨다', () {
      final d = _resolve(_at(6, 59));
      expect(d.expanded, isFalse);
      expect(d.direction, CommuteDirection.toWork);
    });

    test('일과시간(10:20)은 접혀 있고 다음은 퇴근이다', () {
      final d = _resolve(_at(10, 20));
      expect(d.expanded, isFalse);
      expect(d.direction, CommuteDirection.toHome);
    });

    test('퇴근 시간대가 끝난 밤에는 다음이 내일 출근이다', () {
      final d = _resolve(_at(21, 0));
      expect(d.expanded, isFalse);
      expect(d.direction, CommuteDirection.toWork);
    });

    test('자정 직후도 다음은 출근이다', () {
      expect(_resolve(_at(0, 10)).direction, CommuteDirection.toWork);
    });
  });

  group('override — 접기는 그 시간대가 끝날 때까지', () {
    test('출근 시간대에 접으면 같은 시간대 안에서는 접힌 채 있다', () {
      final s = _s.copyWith(overrideAt: _at(7, 10), overrideExpanded: false);
      expect(_resolve(_at(8, 20), settings: s).expanded, isFalse);
    });

    test('그 시간대가 끝나면 만료된다 — 퇴근 시간대에는 다시 펼쳐진다', () {
      final s = _s.copyWith(overrideAt: _at(7, 10), overrideExpanded: false);
      expect(_resolve(_at(16, 30), settings: s).expanded, isTrue);
    });

    test('다음 날 같은 시각에는 만료돼 있다', () {
      final s = _s.copyWith(
        overrideAt: DateTime(2026, 7, 28, 7, 10),
        overrideExpanded: false,
      );
      final tomorrow = DateTime(2026, 7, 29, 7, 30);
      expect(resolveBusDisplay(now: tomorrow, settings: s).expanded, isTrue);
    });
  });

  group('override — 펼치기는 30분', () {
    test('시간대 밖에서 펼치면 29분 뒤에도 펼쳐져 있다', () {
      final s = _s.copyWith(overrideAt: _at(8, 35), overrideExpanded: true);
      expect(_resolve(_at(9, 4), settings: s).expanded, isTrue);
    });

    test('31분 뒤에는 접힘으로 돌아온다 — 일과시간 누수를 막는 지점', () {
      final s = _s.copyWith(overrideAt: _at(8, 35), overrideExpanded: true);
      expect(_resolve(_at(9, 6), settings: s).expanded, isFalse);
    });

    test('기본값에서 08:31 펼침은 09:02에 만료된다', () {
      final s = _s.copyWith(overrideAt: _at(8, 31), overrideExpanded: true);
      expect(_resolve(_at(9, 2), settings: s).expanded, isFalse);
    });
  });

  group('시간대가 무효면 판정을 시도하지 않는다', () {
    test('두 시간대가 겹치면 접힘으로 둔다', () {
      final s = BusSettings.defaults.copyWith(
        toHomeRange: _s.toWorkRange,
      );
      expect(_resolve(_at(7, 30), settings: s).expanded, isFalse);
    });
  });
}
