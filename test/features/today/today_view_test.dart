import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/core/utils/date_utils.dart';
import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/features/today/domain/today_view.dart';

/// 테스트 기준일 — 2026년 7월 25일 토요일.
final _today = DateTime(2026, 7, 25);

CalendarEvent _event({
  required int id,
  required DateTime date,
  String title = '업무 처리',
  bool completed = false,
  bool important = false,
}) {
  return CalendarEvent(
    id: id,
    title: title,
    eventDate: formatDate(date),
    completedAt: completed ? '2026-07-25T09:00:00.000' : null,
    isImportant: important,
  );
}

List<int> _ids(List<CalendarEvent> events) =>
    events.map((e) => e.id ?? -1).toList();

void main() {
  group('buildTodayView — 지난/오늘 분리', () {
    test('오늘 이벤트는 오늘 목록, 어제 이벤트는 지난 목록으로 나뉜다', () {
      final view = buildTodayView(
        events: [
          _event(id: 1, date: _today),
          _event(id: 2, date: _today.subtract(const Duration(days: 1))),
        ],
        today: _today,
      );

      expect(_ids(view.today), [1]);
      expect(_ids(view.overdue), [2]);
    });

    test('7일 전 미완료 이벤트는 지난 목록에 포함된다', () {
      final view = buildTodayView(
        events: [_event(id: 1, date: _today.subtract(const Duration(days: 7)))],
        today: _today,
      );

      expect(_ids(view.overdue), [1]);
    });

    test('8일 전 미완료 이벤트는 컷오프 밖이라 제외된다', () {
      final view = buildTodayView(
        events: [_event(id: 1, date: _today.subtract(const Duration(days: 8)))],
        today: _today,
      );

      expect(view.overdue, isEmpty);
    });

    test('지난 항목 중 이미 완료된 것은 노출하지 않는다', () {
      final view = buildTodayView(
        events: [
          _event(
            id: 1,
            date: _today.subtract(const Duration(days: 2)),
            completed: true,
          ),
          _event(id: 2, date: _today.subtract(const Duration(days: 2))),
        ],
        today: _today,
      );

      expect(_ids(view.overdue), [2]);
    });

    test('지난 목록은 날짜 오름차순(오래된 것 먼저)으로 정렬된다', () {
      final view = buildTodayView(
        events: [
          _event(id: 1, date: _today.subtract(const Duration(days: 1))),
          _event(id: 2, date: _today.subtract(const Duration(days: 5))),
          _event(id: 3, date: _today.subtract(const Duration(days: 3))),
        ],
        today: _today,
      );

      expect(_ids(view.overdue), [2, 3, 1]);
    });

    test('미래 이벤트는 오늘 목록에도 지난 목록에도 들어가지 않는다', () {
      final view = buildTodayView(
        events: [_event(id: 1, date: _today.add(const Duration(days: 1)))],
        today: _today,
      );

      expect(view.today, isEmpty);
      expect(view.overdue, isEmpty);
    });

    test('기준 시각의 시·분은 무시하고 날짜만 비교한다', () {
      final view = buildTodayView(
        events: [_event(id: 1, date: _today)],
        today: DateTime(2026, 7, 25, 23, 59),
      );

      expect(_ids(view.today), [1]);
    });
  });

  group('buildTodayView — 오늘 목록 정렬', () {
    test('중요 미완료 → 일반 미완료 → 완료 순으로 정렬된다', () {
      final view = buildTodayView(
        events: [
          _event(id: 1, date: _today, completed: true),
          _event(id: 2, date: _today),
          _event(id: 3, date: _today, important: true),
        ],
        today: _today,
      );

      expect(_ids(view.today), [3, 2, 1]);
    });

    test('같은 그룹 안에서는 입력 순서를 유지한다', () {
      final view = buildTodayView(
        events: [
          _event(id: 1, date: _today),
          _event(id: 2, date: _today),
          _event(id: 3, date: _today),
        ],
        today: _today,
      );

      expect(_ids(view.today), [1, 2, 3]);
    });
  });

  group('buildTodayView — 진행도', () {
    test('진행도는 오늘 항목만 계산한다 (지난 항목은 섞이지 않는다)', () {
      final view = buildTodayView(
        events: [
          _event(id: 1, date: _today, completed: true),
          _event(id: 2, date: _today),
          _event(id: 3, date: _today.subtract(const Duration(days: 1))),
        ],
        today: _today,
      );

      expect(view.doneCount, 1);
      expect(view.totalCount, 2);
    });

    test('오늘 일정이 없으면 hasToday가 false이고 진행도는 0이다', () {
      final view = buildTodayView(
        events: [_event(id: 1, date: _today.subtract(const Duration(days: 1)))],
        today: _today,
      );

      expect(view.hasToday, isFalse);
      expect(view.isAllDone, isFalse);
    });

    test('오늘 항목이 모두 완료되면 isAllDone이 true다', () {
      final view = buildTodayView(
        events: [
          _event(id: 1, date: _today, completed: true),
          _event(id: 2, date: _today, completed: true),
        ],
        today: _today,
      );

      expect(view.isAllDone, isTrue);
    });

    test('남은 건수는 오늘 미완료 개수다', () {
      final view = buildTodayView(
        events: [
          _event(id: 1, date: _today, completed: true),
          _event(id: 2, date: _today),
          _event(id: 3, date: _today),
        ],
        today: _today,
      );

      expect(view.remainingCount, 2);
    });
  });

  group('TodayView.withToggled — 자리 고정 갱신', () {
    test('완료로 바꿔도 목록 순서가 유지된다', () {
      final view = buildTodayView(
        events: [
          _event(id: 1, date: _today),
          _event(id: 2, date: _today),
        ],
        today: _today,
      );

      final toggled = view.withToggled(1, '2026-07-25T10:00:00.000');

      expect(_ids(toggled.today), [1, 2]);
      expect(toggled.today.first.isCompleted, isTrue);
      expect(toggled.doneCount, 1);
    });

    test('완료 취소하면 completedAt이 null로 돌아간다', () {
      final view = buildTodayView(
        events: [_event(id: 1, date: _today, completed: true)],
        today: _today,
      );

      final toggled = view.withToggled(1, null);

      expect(toggled.today.first.isCompleted, isFalse);
      expect(toggled.doneCount, 0);
    });

    test('지난 항목을 완료해도 목록에서 사라지지 않는다', () {
      final view = buildTodayView(
        events: [_event(id: 1, date: _today.subtract(const Duration(days: 2)))],
        today: _today,
      );

      final toggled = view.withToggled(1, '2026-07-25T10:00:00.000');

      expect(_ids(toggled.overdue), [1]);
      expect(toggled.overdue.first.isCompleted, isTrue);
    });

    test('지난 항목 완료는 오늘 진행도에 영향을 주지 않는다', () {
      final view = buildTodayView(
        events: [
          _event(id: 1, date: _today.subtract(const Duration(days: 2))),
          _event(id: 2, date: _today),
        ],
        today: _today,
      );

      final toggled = view.withToggled(1, '2026-07-25T10:00:00.000');

      expect(toggled.doneCount, 0);
      expect(toggled.totalCount, 1);
    });
  });
}
