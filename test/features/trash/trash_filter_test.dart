import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/features/schedule/domain/schedule.dart';
import 'package:planroutine/features/trash/domain/trash_filter.dart';
import 'package:planroutine/features/trash/presentation/providers/trash_providers.dart';

/// 휴지통에서 **캘린더 이벤트와 짝인 원본 일정**을 감추는 규칙.
///
/// 캘린더에서 하나를 지우면 원본 일정도 함께 내려가므로(연쇄 삭제), 거르지 않으면
/// 휴지통에 같은 항목이 `일정` 한 줄 + `이벤트` 한 줄로 두 번 뜬다.
void main() {
  Schedule schedule(int id, String title) => Schedule(
    id: id,
    title: title,
    scheduledDate: '2026-10-15',
    status: ScheduleStatus.confirmed,
    deletedAt: '2026-10-01T09:00:00.000',
  );

  CalendarEvent event(int id, {int? scheduleId}) => CalendarEvent(
    id: id,
    title: '이벤트 $id',
    eventDate: '2026-10-15',
    scheduleId: scheduleId,
    deletedAt: '2026-10-01T09:00:00.000',
  );

  test('삭제된 이벤트와 짝인 원본 일정은 목록에서 빠진다', () {
    final visible = visibleTrashSchedules(
      [schedule(1, '가을 운동회')],
      [event(10, scheduleId: 1)],
    );

    expect(visible, isEmpty);
  });

  test('짝이 없는 일정은 그대로 보인다 — 입력 탭에서 지운 검토 대기가 여기 속한다', () {
    final visible = visibleTrashSchedules(
      [schedule(1, '가을 운동회'), schedule(2, '검토 대기였던 일정')],
      [event(10, scheduleId: 1)],
    );

    expect(visible.map((s) => s.id), [2]);
  });

  test('삭제된 이벤트가 없으면 모든 일정이 남는다', () {
    final visible = visibleTrashSchedules([schedule(1, '가을 운동회')], []);

    expect(visible.map((s) => s.id), [1]);
  });

  test('손입력 이벤트(schedule_id 없음)는 어떤 일정도 감추지 않는다', () {
    final visible = visibleTrashSchedules(
      [schedule(1, '가을 운동회')],
      [event(10)],
    );

    expect(visible.map((s) => s.id), [1]);
  });

  test('TrashSnapshot이 스스로 감춘다 — 호출부가 거르는 것을 잊을 수 없다', () {
    final snapshot = TrashSnapshot(
      schedules: [schedule(1, '가을 운동회')],
      events: [event(10, scheduleId: 1)],
    );

    expect(snapshot.schedules, isEmpty);
    expect(snapshot.total, 1, reason: '사용자가 지운 것은 하나다');
  });
}
