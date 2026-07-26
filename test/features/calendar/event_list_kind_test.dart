import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/features/calendar/presentation/widgets/event_list_section.dart';
import 'package:planroutine/features/schedule/domain/entry_kind.dart';
import 'package:planroutine/features/schedule/presentation/widgets/kind_badge.dart';

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
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  double cardHeight(WidgetTester tester, int id) {
    return tester.getSize(find.byKey(Key('event_card_$id'))).height;
  }

  group('목록 — 업무 / 학교일정 구분', () {
    testWidgets('업무 행과 학교일정 행에 각각 배지가 붙는다', (tester) async {
      await pump(tester, const [
        CalendarEvent(
          id: 1,
          title: '교육계획 수립',
          eventDate: '2026-03-02',
        ),
        CalendarEvent(
          id: 2,
          title: '가을 운동회',
          eventDate: '2026-03-02',
          kind: EntryKind.event,
        ),
      ]);

      expect(find.byType(KindBadge), findsNWidgets(2));
      expect(find.text('업무'), findsOneWidget);
      expect(find.text('행사'), findsOneWidget);
    });

    testWidgets('중요 행에도 종류 배지가 함께 보이고 제목이 넘치지 않는다',
        (tester) async {
      await pump(tester, const [
        CalendarEvent(
          id: 3,
          title: '2026학년도 학교교육계획 수립 및 심의 요청',
          eventDate: '2026-03-02',
          isImportant: true,
        ),
      ]);

      expect(find.byType(KindBadge), findsOneWidget);
      expect(find.byKey(const Key('event_important_badge_3')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('목록 — 중요 표시는 세로를 쓰지 않는다', () {
    testWidgets('중요 행과 보통 행의 높이가 같다', (tester) async {
      await pump(tester, const [
        CalendarEvent(id: 4, title: '보통 일정', eventDate: '2026-03-02'),
        CalendarEvent(
          id: 5,
          title: '중요 일정',
          eventDate: '2026-03-02',
          isImportant: true,
        ),
      ]);

      expect(cardHeight(tester, 5), cardHeight(tester, 4));
    });

    testWidgets('"중요" 글자는 더 이상 목록에 없다', (tester) async {
      await pump(tester, const [
        CalendarEvent(
          id: 6,
          title: '중요 일정',
          eventDate: '2026-03-02',
          isImportant: true,
        ),
      ]);

      expect(find.text('중요'), findsNothing);
    });
  });
}
