import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/features/calendar/presentation/widgets/calendar_day_cell.dart';
import 'package:planroutine/features/calendar/presentation/widgets/calendar_grid.dart';

/// 날짜 칸은 **무슨 날인지 말하는 버튼**이어야 한다.
///
/// `GestureDetector` + 숫자만 두면 실기 접근성 트리에서 칸이 숫자 `4`로만
/// 잡히거나(MobileBuildMCP) 아예 빠졌다(mobile MCP, 2026-10-04 실측). 몇 월인지,
/// 오늘인지, 공휴일인지, 일정이 있는지는 색과 점으로만 보였다.
void main() {
  group('calendarDaySemanticsLabel', () {
    test('평일은 날짜와 요일만', () {
      expect(
        calendarDaySemanticsLabel(
          date: DateTime(2026, 10, 7),
          isToday: false,
          eventCount: 0,
          hasMemo: false,
        ),
        '10월 7일 수요일',
      );
    });

    test('오늘·공휴일 이름·일정 건수·포스트잇을 차례로 붙인다', () {
      expect(
        calendarDaySemanticsLabel(
          date: DateTime(2026, 10, 9),
          isToday: true,
          holidayName: '한글날',
          eventCount: 2,
          hasMemo: true,
        ),
        '10월 9일 금요일, 오늘, 한글날, 일정 2건, 포스트잇',
      );
    });

    test('일요일과 토요일 이름이 맞다', () {
      String label(DateTime d) => calendarDaySemanticsLabel(
        date: d,
        isToday: false,
        eventCount: 0,
        hasMemo: false,
      );
      expect(label(DateTime(2026, 10, 4)), '10월 4일 일요일');
      expect(label(DateTime(2026, 10, 10)), '10월 10일 토요일');
    });
  });

  testWidgets('칸이 라벨을 가진 버튼이고 선택 상태를 말한다', (tester) async {
    final handle = tester.ensureSemantics();
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarDayCell(
            day: 7,
            semanticLabel: '10월 7일 수요일',
            isToday: false,
            isSelected: true,
            isWeekend: false,
            isCurrentMonth: true,
            isSaturday: false,
            onTap: () => tapped++,
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('10월 7일 수요일')),
      isSemantics(
        label: '10월 7일 수요일',
        isButton: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    tester.semantics.tap(find.semantics.byLabel('10월 7일 수요일'));
    expect(tapped, 1);
    handle.dispose();
  });

  testWidgets('격자가 날짜마다 공휴일·일정까지 담은 라벨을 넘긴다', (tester) async {
    final handle = tester.ensureSemantics();
    DateTime? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarGrid(
            year: 2026,
            month: 10,
            // 실제 오늘이 10월 7일인 날에는 그 칸에 `오늘`이 붙어 이 테스트가 깨졌다(2026-10-07) — 오늘을 고정한다.
            today: DateTime(2026, 10, 20),
            selectedDate: DateTime(2026, 10, 7),
            eventsMap: const {
              '2026-10-07': [
                CalendarEvent(id: 1, title: '학부모 상담', eventDate: '2026-10-07'),
              ],
            },
            memoDates: const {'2026-10-07'},
            onDateSelected: (d) => picked = d,
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('10월 3일 토요일, 개천절')),
      isSemantics(isButton: true, isSelected: false),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('10월 7일 수요일, 일정 1건, 포스트잇')),
      isSemantics(isButton: true, isSelected: true),
    );
    // 앞뒤 달에서 빌려 온 칸도 그 달 이름으로 읽힌다(숫자만으로는 9월 27일과
    // 10월 27일을 가를 수 없다).
    expect(find.bySemanticsLabel('9월 27일 일요일'), findsOneWidget);

    tester.semantics.tap(find.semantics.byLabel('10월 3일 토요일, 개천절'));
    expect(picked, DateTime(2026, 10, 3));
    handle.dispose();
  });

  testWidgets('넘긴 오늘 칸에 `오늘`이 붙는다 — 실제 시계가 아니라 넘긴 날짜를 본다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarGrid(
            year: 2026,
            month: 10,
            today: DateTime(2026, 10, 14),
            selectedDate: DateTime(2026, 10, 1),
            eventsMap: const {},
            onDateSelected: (_) {},
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('10월 14일 수요일, 오늘'), findsOneWidget);
    handle.dispose();
  });
}
