import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/features/calendar/presentation/widgets/calendar_day_cell.dart';

void main() {
  Future<void> pumpCell(
    WidgetTester tester, {
    required List<CalendarEvent> events,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarDayCell(
            day: 2,
            isToday: false,
            isSelected: false,
            isWeekend: false,
            isCurrentMonth: true,
            isSaturday: false,
            onTap: () {},
            events: events,
          ),
        ),
      ),
    );
  }

  Finder star() => find.byKey(const Key('day_important_star'));

  group('CalendarDayCell — 중요 ★ 표시', () {
    testWidgets('미완료 중요 이벤트가 있으면 골드 ★', (tester) async {
      await pumpCell(tester, events: const [
        CalendarEvent(
          id: 1,
          title: '입학식',
          eventDate: '2026-03-02',
          isImportant: true,
        ),
      ]);
      expect(star(), findsOneWidget);
    });

    testWidgets('일반 이벤트만 있으면 ★ 없음', (tester) async {
      await pumpCell(tester, events: const [
        CalendarEvent(id: 2, title: '평범', eventDate: '2026-03-02'),
      ]);
      expect(star(), findsNothing);
    });

    testWidgets('중요하지만 완료된 이벤트만 있으면 ★ 없음', (tester) async {
      await pumpCell(tester, events: const [
        CalendarEvent(
          id: 3,
          title: '끝남',
          eventDate: '2026-03-02',
          isImportant: true,
          completedAt: '2026-03-02T10:00:00.000',
        ),
      ]);
      expect(star(), findsNothing);
    });
  });
}
