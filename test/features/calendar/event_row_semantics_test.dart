import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/features/calendar/presentation/widgets/event_list_section.dart';
import 'package:planroutine/features/schedule/domain/entry_kind.dart';

/// 캘린더 목록의 일정 행은 **무슨 일정인지 말하는 버튼 하나**여야 한다.
///
/// `GestureDetector`만 두면 mobile MCP 목록에 행이 아예 나오지 않아, 일정을 열려면
/// 좌표로 눌러야 했다(2026-10-04 실측).
void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR', null);
  });

  group('eventRowSemanticsLabel', () {
    test('종류와 제목', () {
      expect(
        eventRowSemanticsLabel(
          const CalendarEvent(id: 1, title: '교육계획 수립', eventDate: '2026-03-02'),
        ),
        '업무, 교육계획 수립',
      );
    });

    test('중요·설명·작년·완료를 화면 순서대로 붙인다', () {
      expect(
        eventRowSemanticsLabel(
          const CalendarEvent(
            id: 2,
            title: '가을 운동회',
            description: '운동장',
            eventDate: '2026-03-02',
            kind: EntryKind.event,
            isImportant: true,
            fromImport: true,
          ),
        ),
        '행사, ${CalendarStrings.importantBadge}, 가을 운동회, 운동장, '
        '${CalendarStrings.fromImportBadge}',
      );
      // 완료되면 중요 강조(★)는 꺼지고 완료 표시가 붙는다(`showsImportant`).
      expect(
        eventRowSemanticsLabel(
          const CalendarEvent(
            id: 3,
            title: '학부모 상담',
            eventDate: '2026-03-02',
            isImportant: true,
            completedAt: '2026-03-02T09:00:00',
          ),
        ),
        '업무, 학부모 상담, ${CalendarStrings.eventDone}',
      );
    });
  });

  testWidgets('행이 그 라벨을 가진 버튼이고 시맨틱스 탭이 일정을 연다', (tester) async {
    final handle = tester.ensureSemantics();
    CalendarEvent? opened;
    const event = CalendarEvent(
      id: 7,
      title: '교육계획 수립',
      eventDate: '2026-03-02',
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EventListSection(
                selectedDate: DateTime(2026, 3, 2),
                events: const [event],
                onEventTap: (e) => opened = e,
                onEventSaveToGoogle: null,
                onEventToggleCompleted: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.getSemantics(find.bySemanticsLabel('업무, 교육계획 수립')),
      isSemantics(isButton: true, hasTapAction: true),
    );
    tester.semantics.tap(find.semantics.byLabel('업무, 교육계획 수립'));
    expect(opened, event);
    handle.dispose();
  });
}
