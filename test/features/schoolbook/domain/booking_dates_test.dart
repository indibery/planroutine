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
