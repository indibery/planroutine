/// 대한민국 공휴일 판정 (내장 테이블 — 오프라인·의존성 0).
///
/// 고정 공휴일(신정·삼일절·어린이날·현충일·광복절·개천절·한글날·성탄절)은 규칙으로,
/// 음력 기반(설·추석 연휴, 부처님오신날)과 대체공휴일·선거일은 연도별 테이블로 판정.
/// 테이블 범위 밖 연도는 고정 공휴일만 판정된다(음력·대체는 미상).
///
/// ※ 연도 추가 시: 아래 `_lunarAndSubstitute`에 해당 연도 항목을 한 줄씩 추가.
///   (설·추석 연휴 3일, 부처님오신날, 대체공휴일, 선거일)
///
/// **이름은 데이터다**(2026-08-18). 예전에는 날짜만 담고 이름은 주석에 있었는데,
/// 캘린더 목록에 "어떤 휴일인지" 보여주려면 이름이 필요하다.
///
/// ⚠️ **연휴는 같은 이름을 공유해야 한다.** [koreanHolidayRunAt]이 "연속한 날이 같은
/// 이름이면 한 런"으로 묶으므로, 추석 3일에 각각 다른 이름을 적으면 런이 쪼개져
/// 목록에 세 줄이 뜬다. 붙어 있는 대체공휴일을 연휴에 합치고 싶으면 그것도 같은
/// 이름을 준다(2027 설날 2/6~9가 그 경우다).
///
/// ⚠️ **일요일은 이 표에 없다**(색 규칙이 따로 본다). 그래서 `8/15 광복절(토)` ·
/// `8/16 일` · `8/17 대체(월)`는 실제로 3연휴인데 런이 둘로 끊긴다 — 알고 두는
/// 한계다.
library;

/// 공휴일 런 — 연속한 같은 이름의 공휴일 묶음. 하루짜리는 [start] == [end].
typedef HolidayRun = ({String name, DateTime start, DateTime end});

/// 고정 공휴일 (월, 일) → 이름
const _fixed = <(int, int), String>{
  (1, 1): '신정',
  (3, 1): '삼일절',
  (5, 5): '어린이날',
  (6, 6): '현충일',
  (8, 15): '광복절',
  (10, 3): '개천절',
  (10, 9): '한글날',
  (12, 25): '성탄절',
};

/// 연도별 음력 공휴일 + 대체공휴일 + 선거·임시공휴일 (월, 일) → 이름
const _lunarAndSubstitute = <int, Map<(int, int), String>>{
  2025: {
    (1, 27): '임시공휴일',
    (1, 28): '설날 연휴', (1, 29): '설날 연휴', (1, 30): '설날 연휴',
    (3, 3): '삼일절 대체공휴일',
    (5, 6): '어린이날 대체공휴일',
    (6, 3): '대통령선거',
    (10, 5): '추석 연휴', (10, 6): '추석 연휴', (10, 7): '추석 연휴',
    (10, 8): '추석 연휴', // 대체 — 연휴에 붙여 한 런으로 묶는다
  },
  2026: {
    (2, 16): '설날 연휴', (2, 17): '설날 연휴', (2, 18): '설날 연휴',
    (3, 2): '삼일절 대체공휴일',
    (5, 24): '부처님오신날',
    (5, 25): '부처님오신날 대체공휴일',
    (6, 3): '지방선거',
    (8, 17): '광복절 대체공휴일',
    (9, 24): '추석 연휴', (9, 25): '추석 연휴', (9, 26): '추석 연휴',
    (10, 5): '개천절 대체공휴일',
  },
  2027: {
    (2, 6): '설날 연휴', (2, 7): '설날 연휴', (2, 8): '설날 연휴',
    (2, 9): '설날 연휴', // 대체 — 연휴에 붙여 4일 한 런으로 묶는다
    (5, 13): '부처님오신날',
    (8, 16): '광복절 대체공휴일',
    (9, 14): '추석 연휴', (9, 15): '추석 연휴', (9, 16): '추석 연휴',
    (10, 4): '개천절 대체공휴일',
    (10, 11): '한글날 대체공휴일',
    (12, 27): '성탄절 대체공휴일',
  },
};

/// [date]의 공휴일 이름. 공휴일이 아니면 null.
String? koreanHolidayName(DateTime date) {
  final md = (date.month, date.day);
  return _fixed[md] ?? _lunarAndSubstitute[date.year]?[md];
}

/// [date]가 대한민국 공휴일이면 true.
bool isKoreanHoliday(DateTime date) => koreanHolidayName(date) != null;

/// [date]가 **자기 런의 첫날일 때만** 그 런을 준다. 아니면 null.
///
/// 목록에 연휴를 첫날 한 줄로만 그리기 위한 판정이다 — 둘째 날부터는 null이라
/// 호출부가 조건문을 따로 쓸 필요가 없다.
HolidayRun? koreanHolidayRunAt(DateTime date) {
  final name = koreanHolidayName(date);
  if (name == null) return null;

  final day = DateTime(date.year, date.month, date.day);
  // 앞날이 같은 이름이면 첫날이 아니다.
  if (koreanHolidayName(day.subtract(const Duration(days: 1))) == name) {
    return null;
  }

  var end = day;
  while (koreanHolidayName(end.add(const Duration(days: 1))) == name) {
    end = end.add(const Duration(days: 1));
  }
  return (name: name, start: day, end: end);
}

/// [year]년 [month]월에 **시작하는** 런 목록(시작일 오름차순).
///
/// 달 경계를 넘어온 런(전달에 시작)은 포함하지 않는다 — 그 런은 전달 목록에
/// 이미 한 줄로 그려졌다.
List<HolidayRun> koreanHolidayRunsIn(int year, int month) {
  final last = DateTime(year, month + 1, 0).day;
  final runs = <HolidayRun>[];
  for (var d = 1; d <= last; d++) {
    final run = koreanHolidayRunAt(DateTime(year, month, d));
    if (run != null) runs.add(run);
  }
  return runs;
}
