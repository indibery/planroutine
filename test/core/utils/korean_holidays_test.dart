import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/utils/korean_holidays.dart';

void main() {
  group('isKoreanHoliday — 고정 공휴일', () {
    test('신정·삼일절·어린이날·현충일·광복절·개천절·한글날·성탄절', () {
      expect(isKoreanHoliday(DateTime(2026, 1, 1)), true);
      expect(isKoreanHoliday(DateTime(2026, 3, 1)), true);
      expect(isKoreanHoliday(DateTime(2026, 5, 5)), true);
      expect(isKoreanHoliday(DateTime(2026, 6, 6)), true);
      expect(isKoreanHoliday(DateTime(2026, 8, 15)), true);
      expect(isKoreanHoliday(DateTime(2026, 10, 3)), true);
      expect(isKoreanHoliday(DateTime(2026, 10, 9)), true);
      expect(isKoreanHoliday(DateTime(2026, 12, 25)), true);
    });

    test('평일은 false', () {
      expect(isKoreanHoliday(DateTime(2026, 7, 2)), false);
      expect(isKoreanHoliday(DateTime(2026, 4, 8)), false);
    });
  });

  group('isKoreanHoliday — 음력 공휴일 (설·추석·석가탄신일)', () {
    test('2026 설날 연휴 2/16~18', () {
      expect(isKoreanHoliday(DateTime(2026, 2, 16)), true);
      expect(isKoreanHoliday(DateTime(2026, 2, 17)), true);
      expect(isKoreanHoliday(DateTime(2026, 2, 18)), true);
      expect(isKoreanHoliday(DateTime(2026, 2, 19)), false);
    });

    test('2026 추석 연휴 9/24~26 (학교 행사표 교차 검증)', () {
      expect(isKoreanHoliday(DateTime(2026, 9, 24)), true);
      expect(isKoreanHoliday(DateTime(2026, 9, 25)), true);
      expect(isKoreanHoliday(DateTime(2026, 9, 26)), true);
    });

    test('2026 부처님오신날 5/24, 2027 설날 연휴 2/6~8', () {
      expect(isKoreanHoliday(DateTime(2026, 5, 24)), true);
      expect(isKoreanHoliday(DateTime(2027, 2, 6)), true);
      expect(isKoreanHoliday(DateTime(2027, 2, 7)), true);
      expect(isKoreanHoliday(DateTime(2027, 2, 8)), true);
    });
  });

  group('isKoreanHoliday — 대체공휴일 (학교 행사표 교차 검증)', () {
    test('2026: 삼일절 3/2 · 석가 5/25 · 광복절 8/17 · 개천절 10/5', () {
      expect(isKoreanHoliday(DateTime(2026, 3, 2)), true);
      expect(isKoreanHoliday(DateTime(2026, 5, 25)), true);
      expect(isKoreanHoliday(DateTime(2026, 8, 17)), true);
      expect(isKoreanHoliday(DateTime(2026, 10, 5)), true);
    });

    test('2027: 설 2/9 · 광복절 8/16 · 개천절 10/4 · 한글날 10/11 · 성탄 12/27', () {
      expect(isKoreanHoliday(DateTime(2027, 2, 9)), true);
      expect(isKoreanHoliday(DateTime(2027, 8, 16)), true);
      expect(isKoreanHoliday(DateTime(2027, 10, 4)), true);
      expect(isKoreanHoliday(DateTime(2027, 10, 11)), true);
      expect(isKoreanHoliday(DateTime(2027, 12, 27)), true);
    });

    test('대체 없는 경우: 2026 현충일(토)·2027 현충일(일) 다음 날은 평일', () {
      expect(isKoreanHoliday(DateTime(2026, 6, 8)), false);
      expect(isKoreanHoliday(DateTime(2027, 6, 7)), false);
    });
  });

  group('isKoreanHoliday — 선거일·임시공휴일', () {
    test('2026 지방선거 6/3 (학교 행사표 교차 검증)', () {
      expect(isKoreanHoliday(DateTime(2026, 6, 3)), true);
    });
  });

  group('테이블 범위 밖', () {
    test('범위 밖 연도는 고정 공휴일만이라도 판정 (신정)', () {
      // 테이블 미보유 연도: 고정 공휴일은 계산 가능하므로 true 유지
      expect(isKoreanHoliday(DateTime(2030, 1, 1)), true);
      expect(isKoreanHoliday(DateTime(2030, 7, 15)), false);
    });
  });
}
