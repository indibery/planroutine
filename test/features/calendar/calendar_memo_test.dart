import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/calendar/presentation/widgets/calendar_day_cell.dart';
import 'package:planroutine/features/calendar/presentation/widgets/event_list_section.dart';
import 'package:planroutine/features/memo/domain/memo.dart';
import 'package:planroutine/features/memo/presentation/widgets/memo_calendar_card.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  const memo = Memo(id: 7, text: '공개수업 지도안');

  Widget section({List<Memo> memos = const [], ValueChanged<Memo>? onMemoTap}) =>
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EventListSection(
                selectedDate: DateTime(2026, 10, 17),
                events: const [],
                memos: memos,
                onMemoTap: onMemoTap,
                onEventTap: (_) {},
                onEventSaveToGoogle: (_) {},
                onEventToggleCompleted: (_) {},
              ),
            ),
          ),
        ),
      );

  testWidgets('쪽지만 있는 날은 빈 상태 대신 쪽지 카드가 보인다', (tester) async {
    await tester.pumpWidget(section(memos: [memo]));
    expect(find.byKey(MemoCalendarCard.cardKey(7)), findsOneWidget);
    expect(find.text(CalendarStrings.noEvents), findsNothing);
  });

  testWidgets('쪽지 카드는 밀어서 저장·완료가 되지 않는다(Dismissible 아님)', (tester) async {
    await tester.pumpWidget(section(memos: [memo]));
    expect(
      find.ancestor(of: find.byKey(MemoCalendarCard.cardKey(7)), matching: find.byType(Dismissible)),
      findsNothing,
    );
  });

  testWidgets('쪽지 카드를 누르면 onMemoTap이 불린다', (tester) async {
    Memo? tapped;
    await tester.pumpWidget(section(memos: [memo], onMemoTap: (m) => tapped = m));
    await tester.tap(find.byKey(MemoCalendarCard.cardKey(7)));
    expect(tapped?.id, 7);
  });

  testWidgets('셀에 쪽지가 있으면 네모 점이 찍힌다', (tester) async {
    Widget cell(bool hasMemo) => MaterialApp(
      home: Scaffold(
        body: CalendarDayCell(
          day: 17,
          isToday: false,
          isSelected: false,
          isWeekend: false,
          isCurrentMonth: true,
          isSaturday: false,
          onTap: () {},
          hasMemo: hasMemo,
        ),
      ),
    );
    await tester.pumpWidget(cell(true));
    expect(find.byKey(CalendarDayCell.memoMarkerKey), findsOneWidget);
    await tester.pumpWidget(cell(false));
    expect(find.byKey(CalendarDayCell.memoMarkerKey), findsNothing);
  });
}
