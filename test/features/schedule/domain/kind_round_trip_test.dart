import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/features/schedule/domain/entry_kind.dart';
import 'package:planroutine/features/schedule/domain/schedule.dart';

/// 모델 ↔ DB Map 사이에서 kind가 살아남는지.
///
/// 오늘 탭이 업무만 보여주려면 확정 과정에서 kind가 유실되지 않아야 한다.
void main() {
  group('Schedule.kind', () {
    test('지정하지 않으면 업무다', () {
      const s = Schedule(title: '학급편성', scheduledDate: '2026-03-02');
      expect(s.kind, EntryKind.task);
    });

    test('toMap → fromMap 왕복에서 행사가 유지된다', () {
      const s = Schedule(
        title: '과학의 달 행사',
        scheduledDate: '2026-04-10',
        kind: EntryKind.event,
      );

      final restored = Schedule.fromMap(s.toMap());

      expect(restored.kind, EntryKind.event);
    });

    test('toMap이 DB 컬럼값으로 넣는다', () {
      const s = Schedule(
        title: '과학의 달 행사',
        scheduledDate: '2026-04-10',
        kind: EntryKind.event,
      );

      expect(s.toMap()['kind'], 'event');
    });

    test('kind 컬럼이 없는 Map은 업무로 읽는다 (v7 이전 백업)', () {
      final restored = Schedule.fromMap({
        'title': '옛 일정',
        'scheduled_date': '2025-03-02',
      });

      expect(restored.kind, EntryKind.task);
    });
  });

  group('CalendarEvent.kind', () {
    test('지정하지 않으면 업무다', () {
      const e = CalendarEvent(title: '학급편성', eventDate: '2026-03-02');
      expect(e.kind, EntryKind.task);
    });

    test('toMap → fromMap 왕복에서 행사가 유지된다', () {
      const e = CalendarEvent(
        title: '과학의 달 행사',
        eventDate: '2026-04-10',
        kind: EntryKind.event,
      );

      final restored = CalendarEvent.fromMap(e.toMap());

      expect(restored.kind, EntryKind.event);
      expect(e.toMap()['kind'], 'event');
    });

    test('kind 컬럼이 없는 Map은 업무로 읽는다', () {
      final restored = CalendarEvent.fromMap({
        'title': '옛 이벤트',
        'event_date': '2025-03-02',
      });

      expect(restored.kind, EntryKind.task);
    });
  });
}
