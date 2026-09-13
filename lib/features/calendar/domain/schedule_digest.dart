import '../../../core/constants/app_strings.dart';
import 'calendar_event.dart';

/// 단축어가 물어볼 수 있는 기간.
///
/// 종류를 늘리지 않는다 — 단축어 쪽 선택지가 늘면 사용자가 고르는 비용이 커지고,
/// 임의 날짜 범위는 단축어 자체의 날짜 액션으로 조합하는 편이 낫다.
enum DigestRange {
  today('today'),
  thisWeek('this_week'),
  thisMonth('this_month');

  const DigestRange(this.dbValue);

  /// Swift가 넘기는 값. **표시 이름과 분리한다** — 문구가 바뀌어도 계약은 그대로다.
  final String dbValue;

  /// 모르는 값·null은 오늘로 폴백한다. Swift 쪽 오타가 빈 화면이 아니라
  /// 가장 흔한 질문의 답으로 떨어지게 한다.
  static DigestRange fromValue(String? value) => DigestRange.values.firstWhere(
    (r) => r.dbValue == value,
    orElse: () => DigestRange.today,
  );
}

/// 기간의 시작일과 종료일(둘 다 포함). 시각은 버린다 —
/// `getEventsByDateRange`가 `YYYY-MM-DD` 문자열로 비교하기 때문이다.
({DateTime start, DateTime end}) digestBounds(DateTime now, DigestRange range) {
  final today = DateTime(now.year, now.month, now.day);
  switch (range) {
    case DigestRange.today:
      return (start: today, end: today);
    case DigestRange.thisWeek:
      // ISO 기준 월요일 시작. `weekday`는 월=1, 일=7이다.
      final monday = today.subtract(Duration(days: today.weekday - 1));
      return (start: monday, end: monday.add(const Duration(days: 6)));
    case DigestRange.thisMonth:
      // 다음 달 0일 = 이번 달 말일. 윤년을 직접 계산하지 않는다.
      final last = DateTime(today.year, today.month + 1, 0);
      return (start: DateTime(today.year, today.month, 1), end: last);
  }
}

/// 일정 목록을 사람이 읽는 한 덩어리 텍스트로 만든다.
///
/// **순수 함수다** — DB도 플랫폼도 타지 않는다(`buildTodayView`와 같은 규칙).
/// 단축어는 이 문자열을 그대로 AI 앱에 넘기거나 알림으로 띄운다.
String buildScheduleDigest({
  required List<CalendarEvent> events,
  required DateTime now,
  required DigestRange range,
}) {
  if (events.isEmpty) {
    return switch (range) {
      DigestRange.today => AppIntentsStrings.digestEmptyToday,
      DigestRange.thisWeek => AppIntentsStrings.digestEmptyWeek,
      DigestRange.thisMonth => AppIntentsStrings.digestEmptyMonth,
    };
  }

  final header = switch (range) {
    DigestRange.today => AppIntentsStrings.digestHeaderToday,
    DigestRange.thisWeek => AppIntentsStrings.digestHeaderWeek,
    DigestRange.thisMonth => AppIntentsStrings.digestHeaderMonth,
  };

  // 조회 쿼리가 이미 날짜순으로 주지만, 이 함수는 순수 함수라 호출부의
  // 정렬에 기대지 않는다 — 테스트가 목록을 손으로 만들어 넘긴다.
  final sorted = [...events]
    ..sort((a, b) => a.eventDate.compareTo(b.eventDate));

  final lines = sorted.map((e) {
    final done = e.completedAt != null
        ? ' (${AppIntentsStrings.doneMark})'
        : '';
    return '- ${e.eventDate} [${e.kind.label}] ${e.title}$done';
  });

  return '$header ${sorted.length}건\n${lines.join('\n')}';
}
