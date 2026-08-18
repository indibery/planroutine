// 공휴일이 목록에 나오려면 **날짜 키가 있어야 한다.**
//
// `MonthEventList`는 `groupedEntries`(날짜 → 이벤트)를 받아 날짜별 섹션을 그린다.
// 그래서 일정이 하나도 없는 공휴일(예: 일정 없는 개천절)은 **키가 없어 섹션 자체가
// 생기지 않았다** — 공휴일 행을 그릴 자리가 없다.
//
// 이 함수가 그 달의 공휴일 런 **시작일**을 빈 키로 합쳐 자리를 만든다. 둘째 날부터는
// 합치지 않는다 — 첫날 한 줄이 범위를 말하므로 빈 섹션을 늘릴 이유가 없다.

import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/features/calendar/domain/holiday_month_entries.dart';

void main() {
  group('mergeHolidayKeys', () {
    test('일정 없는 공휴일도 키가 생긴다', () {
      final entries = mergeHolidayKeys(const {}, 2026, 10);

      // 2026-10: 3 개천절 · 5 대체 · 9 한글날
      expect(entries.map((e) => e.key), [
        '2026-10-03',
        '2026-10-05',
        '2026-10-09',
      ]);
      expect(entries.every((e) => e.value.isEmpty), isTrue);
    });

    test('연휴는 첫날만 키가 생긴다 — 빈 섹션을 늘리지 않는다', () {
      final entries = mergeHolidayKeys(const {}, 2026, 9);

      expect(entries.map((e) => e.key), ['2026-09-24']);
    });

    test('기존 일정 키와 합쳐지고 날짜순으로 정렬된다', () {
      final entries = mergeHolidayKeys(const {
        '2026-10-20': [],
        '2026-10-01': [],
      }, 2026, 10);

      expect(entries.map((e) => e.key), [
        '2026-10-01',
        '2026-10-03',
        '2026-10-05',
        '2026-10-09',
        '2026-10-20',
      ]);
    });

    test('같은 날에 일정이 있으면 그 일정을 잃지 않는다', () {
      final entries = mergeHolidayKeys(const {
        '2026-10-03': ['가짜이벤트'],
      }, 2026, 10);

      final oct3 = entries.firstWhere((e) => e.key == '2026-10-03');
      expect(oct3.value, ['가짜이벤트'], reason: '공휴일 키를 덮어써 일정을 날리면 안 된다');
    });

    test('공휴일이 없는 달은 일정 키만 남는다', () {
      final entries = mergeHolidayKeys(const {'2026-07-10': []}, 2026, 7);

      expect(entries.map((e) => e.key), ['2026-07-10']);
    });
  });
}
