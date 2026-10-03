import '../../calendar/domain/calendar_event.dart';
import '../../memo/domain/memo.dart';
import '../../schedule/domain/schedule.dart';

/// 휴지통 한 줄의 종류.
enum TrashKind { schedule, event, memo }

/// 휴지통 한 줄 — 일정·캘린더 이벤트·쪽지 중 하나.
sealed class TrashEntry {
  const TrashEntry();
  TrashKind get kind;
  String? get deletedAt;
}

final class TrashScheduleEntry extends TrashEntry {
  const TrashScheduleEntry(this.schedule);
  final Schedule schedule;
  @override
  TrashKind get kind => TrashKind.schedule;
  @override
  String? get deletedAt => schedule.deletedAt;
}

final class TrashEventEntry extends TrashEntry {
  const TrashEventEntry(this.event);
  final CalendarEvent event;
  @override
  TrashKind get kind => TrashKind.event;
  @override
  String? get deletedAt => event.deletedAt;
}

final class TrashMemoEntry extends TrashEntry {
  const TrashMemoEntry(this.memo);
  final Memo memo;
  @override
  TrashKind get kind => TrashKind.memo;
  @override
  String? get deletedAt => memo.deletedAt;
}

/// 세 종류를 한 목록으로 합쳐 **삭제 시각이 최근인 것부터** 놓는다(사용자 요청 2026-10-03).
/// 종류별 묶음을 고정 순서로 두면 오래전에 지운 일정이 방금 지운 이벤트·쪽지보다 늘 위에
/// 온다. 삭제 시각은 모두 `toIso8601String()`이라 문자열 비교가 곧 시각 비교다.
/// 시각이 없는 항목은 맨 아래, 같은 시각이면 종류 순서(일정·이벤트·쪽지)로 고정한다.
List<TrashEntry> mergeTrashEntries({
  required List<Schedule> schedules,
  required List<CalendarEvent> events,
  required List<Memo> memos,
}) {
  final entries = <TrashEntry>[
    ...schedules.map(TrashScheduleEntry.new),
    ...events.map(TrashEventEntry.new),
    ...memos.map(TrashMemoEntry.new),
  ];
  entries.sort((a, b) {
    final x = a.deletedAt;
    final y = b.deletedAt;
    if (x != y) {
      if (x == null) return 1;
      if (y == null) return -1;
      return y.compareTo(x);
    }
    return a.kind.index.compareTo(b.kind.index);
  });
  return entries;
}
