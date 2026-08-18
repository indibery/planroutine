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

  _runTests();
}

// ── 공휴일 이름과 연휴 범위 ──────────────────────────────────
//
// 캘린더 목록에 "어떤 휴일인지" 보이게 하려면 이름이 필요하다. 이름은 원래
// `korean_holidays.dart`의 **주석에만** 있었다 — 주석을 데이터로 올린다.
//
// 연휴는 **첫날에만** 범위와 함께 적는다(사용자 결정 2026-08-18). 사흘에 세 번
// 같은 이름을 적으면 목록이 시끄럽고, `9/24~26 추석 연휴` 한 줄이 "사흘 쉰다"를
// 더 잘 말한다. 런 판정 규칙은 **연속한 날이 같은 이름을 공유하면 한 런**이다 —
// 그래서 연휴 3일에 같은 이름(`추석 연휴`)을 넣는 것이 자료 작성 규칙이다.
void _runTests() {
  group('koreanHolidayName — 이름', () {
    test('고정 공휴일 이름', () {
      expect(koreanHolidayName(DateTime(2026, 1, 1)), '신정');
      expect(koreanHolidayName(DateTime(2026, 8, 15)), '광복절');
      expect(koreanHolidayName(DateTime(2026, 12, 25)), '성탄절');
    });

    test('음력·대체 공휴일 이름', () {
      expect(koreanHolidayName(DateTime(2026, 9, 25)), '추석 연휴');
      expect(koreanHolidayName(DateTime(2026, 5, 24)), '부처님오신날');
      expect(koreanHolidayName(DateTime(2026, 3, 2)), '삼일절 대체공휴일');
    });

    test('공휴일이 아니면 null', () {
      expect(koreanHolidayName(DateTime(2026, 7, 2)), isNull);
    });

    test('표 범위 밖 연도는 고정 공휴일만 이름이 나온다', () {
      expect(koreanHolidayName(DateTime(2030, 1, 1)), '신정');
      expect(koreanHolidayName(DateTime(2030, 9, 25)), isNull);
    });
  });

  group('koreanHolidayRunAt — 연휴는 첫날에만', () {
    test('연휴 첫날은 범위를 준다', () {
      final run = koreanHolidayRunAt(DateTime(2026, 9, 24));

      expect(run, isNotNull);
      expect(run!.name, '추석 연휴');
      expect(run.start, DateTime(2026, 9, 24));
      expect(run.end, DateTime(2026, 9, 26));
    });

    test('연휴 둘째·셋째 날은 null — 첫날 범위가 이미 말해준다', () {
      expect(koreanHolidayRunAt(DateTime(2026, 9, 25)), isNull);
      expect(koreanHolidayRunAt(DateTime(2026, 9, 26)), isNull);
    });

    test('하루짜리는 시작과 끝이 같다', () {
      final run = koreanHolidayRunAt(DateTime(2026, 10, 3));

      expect(run!.name, '개천절');
      expect(run.start, run.end);
    });

    test('이름이 다르면 붙어 있어도 다른 런이다', () {
      // 2026-05-24 부처님오신날 / 05-25 그 대체공휴일 — 연속이지만 이름이 다르다.
      final first = koreanHolidayRunAt(DateTime(2026, 5, 24));
      final second = koreanHolidayRunAt(DateTime(2026, 5, 25));

      expect(first!.name, '부처님오신날');
      expect(first.end, DateTime(2026, 5, 24));
      expect(second, isNotNull, reason: '이름이 다르므로 이쪽도 자기 런의 첫날이다');
      expect(second!.name, isNot('부처님오신날'));
    });

    test('공휴일이 아니면 null', () {
      expect(koreanHolidayRunAt(DateTime(2026, 7, 2)), isNull);
    });

    test('달 경계를 넘는 연휴도 첫날에서 잡힌다', () {
      // 2025-01-28~30 설날 연휴 — 1월 안이지만 27일 임시공휴일과 이름이 달라
      // 28일이 자기 런의 첫날이다.
      final run = koreanHolidayRunAt(DateTime(2025, 1, 28));

      expect(run!.name, '설날 연휴');
      expect(run.start, DateTime(2025, 1, 28));
      expect(run.end, DateTime(2025, 1, 30));
    });
  });

  group('koreanHolidayRunsIn — 그 달의 런 시작일 목록', () {
    test('2026년 9월은 추석 연휴 하나', () {
      final runs = koreanHolidayRunsIn(2026, 9);

      expect(runs, hasLength(1));
      expect(runs.single.name, '추석 연휴');
      expect(runs.single.start, DateTime(2026, 9, 24));
    });

    test('2026년 10월은 개천절·대체·한글날 셋', () {
      final runs = koreanHolidayRunsIn(2026, 10);

      expect(runs.map((r) => r.start.day), [3, 5, 9]);
    });

    test('공휴일이 없는 달은 빈 목록', () {
      expect(koreanHolidayRunsIn(2026, 7), isEmpty);
    });
  });
}
