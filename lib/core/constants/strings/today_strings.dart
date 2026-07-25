/// 오늘 탭 문자열.
class TodayStrings {
  TodayStrings._();

  static const title = '오늘';

  // 섹션 헤더
  static const overdueSection = '기한이 지난';
  static const todaySection = '오늘';

  // 완료 도장
  static const sealLabel = '완료';

  // 진행도 문안
  static const allDone = '오늘 업무를 모두 닫았습니다';
  static String remaining(int count) => '오늘 $count건 남았습니다';

  // 빈 상태
  static const emptyToday = '오늘 예정된 일정이 없습니다';
  static const emptyTodayHint = '캘린더 탭에서 일정을 추가할 수 있습니다';

  // 지난 섹션 접힘 안내
  static const overdueExpandHint = '탭하면 펼쳐집니다';
  static String overdueCount(int count) => '$count건';
}
