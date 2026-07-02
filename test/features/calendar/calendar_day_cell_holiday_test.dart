import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/features/calendar/presentation/widgets/calendar_day_cell.dart';

void main() {
  Future<void> pumpCell(
    WidgetTester tester, {
    required bool isHoliday,
    bool isSaturday = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarDayCell(
            day: 25,
            isToday: false,
            isSelected: false,
            isWeekend: false,
            isCurrentMonth: true,
            isSaturday: isSaturday,
            isHoliday: isHoliday,
            onTap: () {},
          ),
        ),
      ),
    );
  }

  Color? dayTextColor(WidgetTester tester) =>
      tester.widget<Text>(find.text('25')).style?.color;

  group('CalendarDayCell — 공휴일 표시', () {
    testWidgets('공휴일이면 날짜 숫자가 일요일과 같은 빨강', (tester) async {
      await pumpCell(tester, isHoliday: true);
      expect(dayTextColor(tester), AppColors.calendarWeekend);
    });

    testWidgets('공휴일이 토요일과 겹치면 빨강이 우선', (tester) async {
      await pumpCell(tester, isHoliday: true, isSaturday: true);
      expect(dayTextColor(tester), AppColors.calendarWeekend);
    });

    testWidgets('공휴일 아니면 기본색', (tester) async {
      await pumpCell(tester, isHoliday: false);
      expect(dayTextColor(tester), AppColors.textPrimary);
    });
  });
}
