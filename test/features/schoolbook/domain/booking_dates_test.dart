import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/schoolbook/domain/booking_dates.dart';

void main() {
  group('lastBookableDate — 다음 해 2월 말일', () {
    test('평년', () {
      expect(lastBookableDate(DateTime(2026, 10, 1)), DateTime(2027, 2, 28));
    });
    test('윤년', () {
      expect(lastBookableDate(DateTime(2027, 5, 1)), DateTime(2028, 2, 29));
    });
  });

  group('initialDay — 처음 여는 날', () {
    test('평일이면 그날', () {
      expect(initialDay(DateTime(2026, 10, 16, 15, 30)), DateTime(2026, 10, 16));
    });
    test('토요일이면 다음 월요일', () {
      expect(initialDay(DateTime(2026, 10, 17)), DateTime(2026, 10, 19));
    });
    test('일요일이면 다음 월요일', () {
      expect(initialDay(DateTime(2026, 10, 18)), DateTime(2026, 10, 19));
    });
  });

  group('nextWeekday / previousWeekday — 평일만 하루씩', () {
    test('금요일 다음은 월요일', () {
      expect(nextWeekday(DateTime(2026, 10, 16), DateTime(2026, 10, 16)),
          DateTime(2026, 10, 19));
    });
    test('마지막 예약 가능일 다음은 없다', () {
      expect(nextWeekday(DateTime(2027, 2, 26), DateTime(2026, 10, 17)), isNull);
    });
    test('월요일 전은 금요일', () {
      expect(previousWeekday(DateTime(2026, 10, 19)), DateTime(2026, 10, 16));
    });
  });

  group('주간 띠 — weekOf · previousWeek · nextWeek', () {
    test('그 주의 월~금 다섯 날', () {
      expect(weekOf(DateTime(2026, 10, 22, 13)), [
        DateTime(2026, 10, 19),
        DateTime(2026, 10, 20),
        DateTime(2026, 10, 21),
        DateTime(2026, 10, 22),
        DateTime(2026, 10, 23),
      ]);
    });
    test('지난주는 같은 요일 7일 전 — 하한 없음', () {
      expect(previousWeek(DateTime(2026, 10, 20)), DateTime(2026, 10, 13));
    });
    test('다음 주는 같은 요일 7일 뒤', () {
      expect(nextWeek(DateTime(2026, 10, 20), DateTime(2026, 10, 17)), DateTime(2026, 10, 27));
    });
    test('다음 주 월요일이 마지막 예약 가능일을 넘으면 없다', () {
      // 마지막 예약 가능일 2027-02-28(일) — 그 주가 마지막 주다
      expect(nextWeek(DateTime(2027, 2, 24), DateTime(2026, 10, 17)), isNull);
      expect(nextWeek(DateTime(2027, 2, 17), DateTime(2026, 10, 17)), DateTime(2027, 2, 24));
    });
    test('다음 주의 같은 요일이 범위 밖이어도 그 주 월요일이 범위 안이면 그 주의 마지막 날로', () {
      // 2028-02-29(화)가 마지막 날일 때 2028-02-25(금) → 다음 주 금요일(03-03)은 밖 → 02-29
      expect(nextWeek(DateTime(2028, 2, 25), DateTime(2027, 5, 1)), DateTime(2028, 2, 29));
    });
  });

  group('isBookableDate', () {
    final today = DateTime(2026, 10, 16);
    test('어제는 아니다', () {
      expect(isBookableDate(DateTime(2026, 10, 15), today), isFalse);
    });
    test('오늘(평일)은 된다', () {
      expect(isBookableDate(DateTime(2026, 10, 16, 23, 59), today), isTrue);
    });
    test('토요일은 아니다', () {
      expect(isBookableDate(DateTime(2026, 10, 17), today), isFalse);
    });
    test('다음 학년도는 아니다', () {
      expect(isBookableDate(DateTime(2027, 3, 1), today), isFalse);
    });
  });
}
