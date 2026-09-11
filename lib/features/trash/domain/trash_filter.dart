import '../../calendar/domain/calendar_event.dart';
import '../../schedule/domain/schedule.dart';

/// 휴지통에 보여줄 일정 목록 — **캘린더 이벤트와 짝인 원본 일정은 감춘다.**
///
/// 캘린더에서 일정을 지우면 원본 행(`schedules`)도 함께 내려가므로
/// (`CalendarRepository.deleteEvent`), 거르지 않으면 하나를 지웠는데 휴지통에
/// `일정` 한 줄과 `이벤트` 한 줄이 따로 떠서 복구도 두 번 눌러야 한다.
/// 짝이 있는 항목은 이벤트 줄이 대표하고, 복구·영구삭제는 그쪽에서 연쇄로 처리된다.
///
/// 짝이 없는 일정은 그대로 남는다 — 입력 탭 검토 목록에서 왼쪽 스와이프로 지운
/// 검토 대기 일정이 여기 속하고, 그것을 되돌릴 길은 휴지통 하나뿐이다.
List<Schedule> visibleTrashSchedules(
  List<Schedule> schedules,
  List<CalendarEvent> deletedEvents,
) {
  final linked = deletedEvents
      .map((e) => e.scheduleId)
      .whereType<int>()
      .toSet();
  if (linked.isEmpty) return schedules;
  return schedules.where((s) => !linked.contains(s.id)).toList();
}
