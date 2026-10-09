import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/bus/domain/arrival_text.dart';

void main() {
  group('arrivalClockText — 간단히 모양의 분·초 표기', () {
    test('1분 이상은 분과 두 자리 초', () {
      expect(arrivalClockText(134), '2분 14초');
      expect(arrivalClockText(60), '1분 00초');
      expect(arrivalClockText(605), '10분 05초');
    });

    test('1분 미만은 초만', () {
      expect(arrivalClockText(48), '48초');
      expect(arrivalClockText(1), '1초');
    });

    test('0초 이하는 곧 도착 — 남은 시간은 0에서 멈춘다', () {
      expect(arrivalClockText(0), '곧 도착');
      expect(arrivalClockText(-3), '곧 도착');
    });
  });

  group('busSignalOf — 분으로 임박도를 가른다', () {
    test('3분 미만은 near', () {
      expect(busSignalOf(0), BusSignal.near);
      expect(busSignalOf(2), BusSignal.near);
    });

    test('3~7분은 soon', () {
      expect(busSignalOf(3), BusSignal.soon);
      expect(busSignalOf(7), BusSignal.soon);
    });

    test('8분부터 far', () {
      expect(busSignalOf(8), BusSignal.far);
      expect(busSignalOf(40), BusSignal.far);
    });
  });

  test('초 표기의 분은 내림이다 — 2분 59초가 3분 칸(soon)으로 가지 않는다', () {
    // 화면에 `2분 59초`라고 쓰면서 색은 반올림한 3분(노랑)으로 칠하면, 사용자가 읽는
    // 숫자와 색이 어긋난다. 간단히 모양은 보이는 분(내림)으로 신호를 고른다.
    expect(displayedMinutes(179), 2);
    expect(busSignalOf(displayedMinutes(179)), BusSignal.near);
  });
}
