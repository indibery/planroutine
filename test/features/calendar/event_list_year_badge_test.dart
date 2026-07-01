import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/features/calendar/presentation/widgets/event_list_section.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR', null);
  });

  final currentYear = DateTime.now().year;
  final oldYear = currentYear - 1;

  Future<void> pumpList(WidgetTester tester, String title) async {
    final event = CalendarEvent(id: 1, title: title, eventDate: '$currentYear-01-03');
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EventListSection(
              selectedDate: DateTime(currentYear, 1, 3),
              events: [event],
              onEventTap: (_) {},
              onEventSaveToGoogle: null,
              onEventToggleCompleted: (_) {},
              onEventBumpYear: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('캘린더 리스트 — 이전 연도 자료 배지', () {
    testWidgets('제목에 이전 연도가 있으면 배지가 보인다', (tester) async {
      await pumpList(tester, '$oldYear학년도 1차 학급편성 결과 제출');
      expect(find.byKey(const Key('year_bump_badge_1')), findsOneWidget);
    });

    testWidgets('이전 연도가 없으면 배지가 없다', (tester) async {
      await pumpList(tester, '졸업식 학사일정 변경 안내');
      expect(find.byKey(const Key('year_bump_badge_1')), findsNothing);
    });

    testWidgets('배지를 탭하면 해당 이벤트로 onEventBumpYear가 호출된다', (tester) async {
      CalendarEvent? tapped;
      final event =
          CalendarEvent(id: 7, title: '$oldYear학년도 겨울방학 계획', eventDate: '$currentYear-01-03');
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: EventListSection(
                selectedDate: DateTime(currentYear, 1, 3),
                events: [event],
                onEventTap: (_) {},
                onEventSaveToGoogle: null,
                onEventToggleCompleted: (_) {},
                onEventBumpYear: (e) => tapped = e,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('year_bump_badge_7')));
      await tester.pump();

      expect(tapped?.id, 7);
    });
  });
}
