// 공휴일은 **수정할 수 없는 일정**으로 목록에 뜬다(사용자 요구 2026-08-18).
//
// 캘린더에서 빨간 날은 보이는데 무슨 휴일인지 알 수 없었다. 이름을 목록에 넣되,
// 사용자 일정과 같은 취급을 하면 안 된다 — 스와이프로 확정·완료·삭제할 대상이
// 아니고, 탭해서 편집할 것도 아니다.
//
// 연휴는 **첫날에만** 범위와 함께 뜬다. 둘째 날부터 `koreanHolidayRunAt`이 null을
// 주므로 이 위젯에는 조건문이 없다.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/features/calendar/presentation/widgets/event_list_section.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('ko_KR', null));

  Future<void> pump(
    WidgetTester tester,
    DateTime date, {
    List<CalendarEvent> events = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EventListSection(
                selectedDate: date,
                events: events,
                onEventTap: (_) {},
                onEventSaveToGoogle: (_) {},
                onEventToggleCompleted: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('공휴일 행', () {
    testWidgets('하루짜리 공휴일은 이름만 뜬다', (tester) async {
      await pump(tester, DateTime(2026, 10, 3));

      expect(find.text('개천절'), findsOneWidget);
    });

    testWidgets('연휴 첫날은 이름과 날짜 범위가 함께 뜬다', (tester) async {
      await pump(tester, DateTime(2026, 9, 24));

      expect(find.text('추석 연휴'), findsOneWidget);
      expect(find.textContaining('9.24'), findsOneWidget);
      expect(find.textContaining('9.26'), findsOneWidget);
    });

    testWidgets('연휴 둘째 날에는 행이 없다 — 첫날 범위가 말해준다', (tester) async {
      await pump(tester, DateTime(2026, 9, 25));

      expect(find.text('추석 연휴'), findsNothing);
    });

    testWidgets('공휴일이 아니면 행이 없다', (tester) async {
      await pump(tester, DateTime(2026, 7, 2));

      expect(find.byKey(const Key('holiday_row')), findsNothing);
    });

    // **급소**: 사용자 일정과 같은 취급을 받으면 스와이프로 확정·삭제된다.
    testWidgets('수정할 수 없다 — Dismissible이 아니다', (tester) async {
      await pump(tester, DateTime(2026, 10, 3));

      expect(
        find.descendant(
          of: find.byKey(const Key('holiday_row')),
          matching: find.byType(Dismissible),
        ),
        findsNothing,
        reason: '공휴일은 스와이프 대상이 아니다',
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('holiday_row')),
          matching: find.byType(InkWell),
        ),
        findsNothing,
        reason: '탭해서 편집할 것도 아니다',
      );
    });

    testWidgets('일정이 없어도 빈 상태 문구 대신 공휴일 행이 뜬다', (tester) async {
      await pump(tester, DateTime(2026, 10, 3));

      expect(find.byKey(const Key('holiday_row')), findsOneWidget);
      expect(find.text('일정이 없습니다'), findsNothing);
    });
  });
}
