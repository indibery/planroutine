import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/bus/domain/time_range.dart';

DateTime _at(int hour, int minute) => DateTime(2026, 7, 28, hour, minute);

void main() {
  const toWork = TimeRange.hm(7, 0, 8, 30);

  group('contains — 경계', () {
    test('시작 정각은 포함, 1분 전은 제외', () {
      expect(toWork.contains(_at(7, 0)), isTrue);
      expect(toWork.contains(_at(6, 59)), isFalse);
    });

    test('종료 정각은 포함, 1분 후는 제외', () {
      expect(toWork.contains(_at(8, 30)), isTrue);
      expect(toWork.contains(_at(8, 31)), isFalse);
    });
  });

  group('isValid', () {
    test('시작이 종료보다 빠르면 유효하다', () {
      expect(const TimeRange.hm(7, 0, 8, 30).isValid, isTrue);
    });

    test('시작과 종료가 같거나 뒤집히면 무효다 — 자정 넘김은 지원하지 않는다', () {
      expect(const TimeRange.hm(8, 30, 8, 30).isValid, isFalse);
      expect(const TimeRange.hm(22, 0, 2, 0).isValid, isFalse);
    });
  });

  group('overlaps', () {
    test('기본값 두 시간대는 겹치지 않는다', () {
      expect(toWork.overlaps(const TimeRange.hm(16, 0, 18, 0)), isFalse);
    });

    test('한쪽 끝이 맞물리면 겹친 것으로 본다', () {
      expect(toWork.overlaps(const TimeRange.hm(8, 30, 10, 0)), isTrue);
    });

    test('완전히 품으면 겹친다', () {
      expect(toWork.overlaps(const TimeRange.hm(6, 0, 20, 0)), isTrue);
    });
  });

  test('label은 설정 타일에 쓰는 07:00 – 08:30 형식이다', () {
    expect(toWork.label, '07:00 – 08:30');
  });

  test('직렬화 왕복', () {
    final back = TimeRange.fromJson(toWork.toJson());
    expect(back.startMinutes, toWork.startMinutes);
    expect(back.endMinutes, toWork.endMinutes);
  });
}
