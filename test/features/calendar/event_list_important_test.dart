import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/features/calendar/presentation/widgets/event_list_section.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR', null);
  });

  Future<void> pump(WidgetTester tester, List<CalendarEvent> events) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EventListSection(
                selectedDate: DateTime(2026, 3, 2),
                events: events,
                onEventTap: (_) {},
                onEventSaveToGoogle: null,
                onEventToggleCompleted: (_) {},
                onEventBumpYear: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Color railColor(WidgetTester tester, int id) {
    final container = tester.widget<Container>(
      find.byKey(Key('event_accent_bar_$id')),
    );
    return (container.decoration as BoxDecoration).color!;
  }

  group('목록 — 중요 이벤트 강조', () {
    testWidgets('중요 이벤트는 ★ 중요 배지 + 골드 레일', (tester) async {
      await pump(tester, const [
        CalendarEvent(
          id: 1,
          title: '시업식',
          eventDate: '2026-03-02',
          isImportant: true,
        ),
      ]);

      expect(find.byKey(const Key('event_important_badge_1')), findsOneWidget);
      expect(railColor(tester, 1), AppColors.gold);
    });

    testWidgets('일반 이벤트는 중요 배지 없음 + 네이비 레일', (tester) async {
      await pump(tester, const [
        CalendarEvent(id: 2, title: '평범한 일정', eventDate: '2026-03-02'),
      ]);

      expect(find.byKey(const Key('event_important_badge_2')), findsNothing);
      expect(railColor(tester, 2), AppColors.eventAccent);
    });

    testWidgets('완료된 중요 이벤트는 배지를 숨기고 레일은 흐리게', (tester) async {
      await pump(tester, const [
        CalendarEvent(
          id: 3,
          title: '끝난 중요 일정',
          eventDate: '2026-03-02',
          isImportant: true,
          completedAt: '2026-03-02T10:00:00.000',
        ),
      ]);

      expect(find.byKey(const Key('event_important_badge_3')), findsNothing);
      expect(railColor(tester, 3), AppColors.faint);
    });
  });
}
