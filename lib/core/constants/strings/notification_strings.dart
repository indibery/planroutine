/// 알림 설정 UI 문자열.
class NotificationStrings {
  NotificationStrings._();

  static const section = '알림';
  static const master = '알림 사용';
  static const masterDescription = '이번 주·당일 아침에 알림을 보냅니다';

  static const weekly = '이번 주 알림 (월요일)';
  static const dayOf = '당일 아침 알림';
  static const time = '알림 시각';

  /// Android 알림 채널의 이름·설명. **`설정 › 앱 › 공직플랜 › 알림`에 그대로
  /// 노출되는 UI 문자열**이라 하드코딩 금지 규칙이 그대로 걸린다
  /// (채널 **id**는 예외 — `notification_details.dart`의 `kAndroidChannelId`).
  ///
  /// ⚠️ [digestTitle]과 값이 같아 보이지만 **공유하지 않는다.** 하나는 알림 제목이고
  /// 하나는 채널 이름이라 청중이 다르다. 공유하면 알림 제목만 고치려던 변경이
  /// 사용자에게는 **채널 이름이 바뀐 것**으로 보인다.
  static const channelName = '일정 알림';
  static const channelDescription = '오늘·이번 주 일정을 아침에 알려줍니다';

  // 통합 알림 본문 — 같은 시각 발송분을 한 알림으로 합칠 때 사용 (이모지 스캔형).
  static const digestTitle = '일정 알림';
  static const digestToday = '오늘';
  static const digestWeek = '이번 주';

  /// 본문 섹션 앞에 붙는 이모지 앵커.
  static const emojiToday = '📅';
  static const emojiWeek = '🗓';

  /// 섹션 제목을 다 못 보일 때의 잔여 개수 표기.
  static String digestOverflow(int rest) => '외 $rest건';

  static const advanced = '고급';

  // 테스트 / 디버그
  static const test = '테스트 알림 보내기';
  static const testScheduled = '5초 후 알림이 발송됩니다. 앱을 벗어나 대기해주세요';
  static const debug = '예약된 알림 보기';
  static const debugEmpty = '예약된 알림이 없습니다';
  static const debugTitle = '예약된 알림';
  static const debugCountSuffix = '개';
}
