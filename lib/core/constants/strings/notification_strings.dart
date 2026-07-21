/// 알림 설정 UI 문자열.
class NotificationStrings {
  NotificationStrings._();

  static const section = '알림';
  static const master = '알림 사용';
  static const masterDescription = '월초·1주 전·당일 아침에 알림을 보냅니다';

  static const monthStart = '월초 알림';
  static const weekBefore = '1주 전 알림';
  static const dayOf = '당일 아침 알림';
  static const time = '알림 시각';

  // 통합 알림 본문 — 같은 시각 발송분을 한 알림으로 합칠 때 사용.
  static const digestTitle = '일정 알림';
  static const digestToday = '오늘';
  static const digestWeek = '1주 후';
  static const digestMonth = '이달';

  /// 섹션 제목을 다 못 보일 때의 잔여 개수 표기.
  static String digestOverflow(int rest) => '외 $rest건';

  /// 이달 섹션의 그 달 전체 건수 표기.
  static String digestMonthTotal(int count) => '총 $count건';

  /// 이달 섹션에서 중요표시된 이벤트 제목 앞에 붙는 라벨.
  static const digestImportant = '중요';

  static const advanced = '고급';

  // 테스트 / 디버그
  static const test = '테스트 알림 보내기';
  static const testScheduled = '5초 후 알림이 발송됩니다. 앱을 벗어나 대기해주세요';
  static const debug = '예약된 알림 보기';
  static const debugEmpty = '예약된 알림이 없습니다';
  static const debugTitle = '예약된 알림';
  static const debugCountSuffix = '개';
}
