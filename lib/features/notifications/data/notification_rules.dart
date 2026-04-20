import '../../calendar/domain/calendar_event.dart';
import '../domain/notification_settings.dart';
import '../domain/pending_notification.dart';

/// iOS는 앱당 64개 예약 알림 상한. 월초 1개 + 안전 버퍼 포함 60개까지만 생성.
const int kMaxPendingNotifications = 60;

/// 알림 ID 네임스페이스.
/// 월초: `1_YYYYMM` (예: 1202607 → 2026년 7월)
/// 이벤트 알림: `2_EVENTID_DAYS` (예: 2_4213_7, 2_4213_1)
/// int 오버플로 방지 위해 단순 해시 스킴 (sqflite rowid + 타입 조합).
int _monthStartId(int year, int month) => 100000000 + year * 100 + month;
int _eventReminderId(int eventId, int daysBefore) =>
    200000000 + eventId * 10 + daysBefore;

/// 주어진 [events]/[settings]/[now] 기준으로 예약할 알림을 계산.
///
/// 순수 함수 — DB/플랫폼/IO 없음, 유닛 테스트 용이.
///
/// 규칙:
///   - masterEnabled가 false면 빈 리스트
///   - completed/deleted 이벤트는 대상 제외
///   - scheduledAt이 [now] 이후인 것만 포함 (과거 시각은 iOS가 즉시 발송하므로 배제)
///   - 월초 알림은 **각 월마다 1개** — 해당 월에 활성 이벤트가 하나 이상 있을 때만
///   - 생성 수가 [kMaxPendingNotifications]를 초과하면 가까운 시각 우선 정렬 후 절단
List<PendingNotification> computeNotifications({
  required List<CalendarEvent> events,
  required NotificationSettings settings,
  required DateTime now,
}) {
  if (!settings.masterEnabled) return [];

  final activeEvents = events
      .where((e) => e.deletedAt == null && e.completedAt == null)
      .toList();

  final pendings = <PendingNotification>[];

  // 월초 알림: 활성 이벤트가 있는 월마다 1개
  if (settings.monthStartEnabled) {
    final byMonth = <String, List<CalendarEvent>>{};
    for (final event in activeEvents) {
      final date = DateTime.tryParse(event.eventDate);
      if (date == null) continue;
      final key = '${date.year}-${date.month}';
      byMonth.putIfAbsent(key, () => []).add(event);
    }
    byMonth.forEach((key, monthEvents) {
      final parts = key.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final scheduledAt = DateTime(
        year,
        month,
        1,
        settings.hour,
        settings.minute,
      );
      if (scheduledAt.isAfter(now)) {
        pendings.add(PendingNotification(
          id: _monthStartId(year, month),
          title: '$month월 일정 알림',
          body: '$month월 일정 ${monthEvents.length}건이 있습니다',
          scheduledAt: scheduledAt,
        ));
      }
    });
  }

  // 이벤트 1주 전 / 1일 전
  for (final event in activeEvents) {
    final eventId = event.id;
    if (eventId == null) continue;
    final eventDate = DateTime.tryParse(event.eventDate);
    if (eventDate == null) continue;
    final eventStart = DateTime(
      eventDate.year,
      eventDate.month,
      eventDate.day,
      settings.hour,
      settings.minute,
    );

    if (settings.weekBeforeEnabled) {
      final at = eventStart.subtract(const Duration(days: 7));
      if (at.isAfter(now)) {
        pendings.add(PendingNotification(
          id: _eventReminderId(eventId, 7),
          title: '1주 앞 일정',
          body: '"${event.title}" 일정이 1주 남았습니다',
          scheduledAt: at,
        ));
      }
    }
    if (settings.dayBeforeEnabled) {
      final at = eventStart.subtract(const Duration(days: 1));
      if (at.isAfter(now)) {
        pendings.add(PendingNotification(
          id: _eventReminderId(eventId, 1),
          title: '내일 일정',
          body: '내일 "${event.title}" 일정이 있습니다',
          scheduledAt: at,
        ));
      }
    }
  }

  // 시각 오름차순 정렬 후 iOS 상한에 맞춰 절단
  pendings.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  if (pendings.length > kMaxPendingNotifications) {
    return pendings.sublist(0, kMaxPendingNotifications);
  }
  return pendings;
}
