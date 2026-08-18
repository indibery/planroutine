/// 공휴일 날짜 키를 월 목록에 합친다.
///
/// `MonthEventList`는 `groupedEntries`(날짜 → 이벤트)를 받아 날짜별 섹션을 그린다.
/// 그래서 **일정이 하나도 없는 공휴일은 키가 없어 섹션 자체가 생기지 않았다** —
/// 공휴일 행을 그릴 자리가 없다. 이 함수가 그 자리를 만든다.
///
/// 합치는 것은 런의 **첫날뿐**이다. 둘째 날부터 합치면 빈 섹션이 늘어나는데,
/// 첫날 한 줄이 이미 범위(`9/24~26`)를 말하므로 얻는 게 없다.
///
/// 제네릭인 이유: 값 타입을 몰라도 되는 순수 자료 조작이고, 그래야 테스트가
/// `CalendarEvent`를 만들지 않고 문자열로 검증할 수 있다.
library;

import '../../../core/utils/date_utils.dart';
import '../../../core/utils/korean_holidays.dart';

/// [byDate]에 [year]년 [month]월 공휴일 런 시작일을 **빈 목록으로** 더해
/// 날짜순 정렬된 항목 목록을 만든다. 이미 있는 날짜의 값은 보존한다.
List<MapEntry<String, List<T>>> mergeHolidayKeys<T>(
  Map<String, List<T>> byDate,
  int year,
  int month,
) {
  final merged = Map<String, List<T>>.of(byDate);
  for (final run in koreanHolidayRunsIn(year, month)) {
    // `putIfAbsent` — 같은 날 일정이 있으면 덮어쓰지 않는다.
    merged.putIfAbsent(formatDate(run.start), () => <T>[]);
  }
  return merged.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
}
