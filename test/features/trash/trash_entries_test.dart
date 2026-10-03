import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/features/memo/domain/memo.dart';
import 'package:planroutine/features/schedule/domain/schedule.dart';
import 'package:planroutine/features/trash/domain/trash_entries.dart';
import 'package:planroutine/features/trash/presentation/providers/trash_providers.dart';

/// 휴지통은 **종류와 상관없이 최근에 지운 것이 위**다(사용자 요청 2026-10-03).
/// 예전에는 일정 → 이벤트 → 포스트잇 묶음 순서가 고정이라, 오래전에 지운 일정이
/// 방금 지운 이벤트·쪽지보다 늘 위에 있었다.
void main() {
  Schedule schedule(int id, String at, {String title = '일정'}) => Schedule(
    id: id,
    title: title,
    scheduledDate: '2026-10-15',
    status: ScheduleStatus.pending,
    deletedAt: at,
  );
  CalendarEvent event(int id, String at, {int? scheduleId}) => CalendarEvent(
    id: id,
    title: '이벤트 $id',
    eventDate: '2026-10-15',
    scheduleId: scheduleId,
    deletedAt: at,
  );
  Memo memo(int id, String at) => Memo(id: id, text: '쪽지 $id', deletedAt: at);

  test('종류와 상관없이 삭제 시각이 최근인 것부터', () {
    final entries = mergeTrashEntries(
      schedules: [schedule(1, '2026-09-01T09:00:00.000')],
      events: [event(10, '2026-10-03T09:00:00.000')],
      memos: [memo(20, '2026-10-02T09:00:00.000')],
    );
    expect(entries.map((e) => e.kind), [
      TrashKind.event,
      TrashKind.memo,
      TrashKind.schedule,
    ]);
  });

  test('삭제 시각이 없는 항목은 맨 아래로', () {
    final entries = mergeTrashEntries(
      schedules: [schedule(1, '2026-09-01T09:00:00.000')],
      events: const [],
      memos: [const Memo(id: 20, text: '시각 없음')],
    );
    expect(entries.map((e) => e.kind), [TrashKind.schedule, TrashKind.memo]);
  });

  test('스냅숏의 합친 목록도 이벤트와 짝인 원본 일정을 감춘다', () {
    final snap = TrashSnapshot(
      schedules: [
        schedule(1, '2026-10-03T09:00:00.000', title: '짝'),
        schedule(2, '2026-09-01T09:00:00.000', title: '혼자'),
      ],
      events: [event(10, '2026-10-03T09:00:00.000', scheduleId: 1)],
    );
    expect(snap.entries, hasLength(2));
    expect(snap.entries.first.kind, TrashKind.event);
    expect(snap.entries.last.kind, TrashKind.schedule);
    expect(snap.total, 2);
  });
}
