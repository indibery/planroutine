import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/calendar_event.dart';
import 'calendar_day_cell.dart';

/// 월간 캘린더 그리드 위젯
class CalendarGrid extends StatelessWidget {
  const CalendarGrid({
    super.key,
    required this.year,
    required this.month,
    required this.selectedDate,
    required this.eventsMap,
    required this.onDateSelected,
  });

  final int year;
  final int month;
  final DateTime selectedDate;
  final Map<String, List<CalendarEvent>> eventsMap;
  final ValueChanged<DateTime> onDateSelected;

  static const _weekdays = [
    AppStrings.weekdaySun,
    AppStrings.weekdayMon,
    AppStrings.weekdayTue,
    AppStrings.weekdayWed,
    AppStrings.weekdayThu,
    AppStrings.weekdayFri,
    AppStrings.weekdaySat,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildWeekdayHeader(),
        const SizedBox(height: AppSizes.spacing4),
        _buildDayGrid(),
      ],
    );
  }

  Widget _buildWeekdayHeader() {
    return Row(
      children: List.generate(7, (index) {
        Color textColor;
        if (index == 0) {
          textColor = AppColors.calendarWeekend;
        } else if (index == 6) {
          textColor = AppColors.calendarSaturday;
        } else {
          textColor = AppColors.textSecondary;
        }
        return Expanded(
          child: Center(
            child: Text(
              _weekdays[index],
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDayGrid() {
    final cells = _buildCalendarCells();
    final rowCount = (cells.length / 7).ceil();

    return Column(
      children: List.generate(rowCount, (rowIndex) {
        final start = rowIndex * 7;
        final end = (start + 7).clamp(0, cells.length);
        final rowCells = cells.sublist(start, end);

        return Row(
          children: rowCells.map((cell) => Expanded(child: cell)).toList(),
        );
      }),
    );
  }

  List<Widget> _buildCalendarCells() {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday % 7; // 일=0, 월=1, ..., 토=6
    final today = DateTime.now();
    final cells = <Widget>[];

    // 이전 달 빈 셀
    final prevMonth = month == 1 ? 12 : month - 1;
    final prevYear = month == 1 ? year - 1 : year;
    final daysInPrevMonth = DateTime(prevYear, prevMonth + 1, 0).day;

    for (var i = 0; i < firstWeekday; i++) {
      final day = daysInPrevMonth - firstWeekday + 1 + i;
      final date = DateTime(prevYear, prevMonth, day);
      final dateStr = formatDate(date);
      cells.add(CalendarDayCell(
        day: day,
        isToday: false,
        isSelected: false,
        isWeekend: i == 0,
        isSaturday: i == 6,
        isCurrentMonth: false,
        events: eventsMap[dateStr] ?? [],
        onTap: () => onDateSelected(date),
      ));
    }

    // 이번 달 셀
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final dateStr = formatDate(date);
      final weekday = (firstWeekday + day - 1) % 7;

      cells.add(CalendarDayCell(
        day: day,
        isToday: date.year == today.year &&
            date.month == today.month &&
            date.day == today.day,
        isSelected: date.year == selectedDate.year &&
            date.month == selectedDate.month &&
            date.day == selectedDate.day,
        isWeekend: weekday == 0,
        isSaturday: weekday == 6,
        isCurrentMonth: true,
        events: eventsMap[dateStr] ?? [],
        onTap: () => onDateSelected(date),
      ));
    }

    // 다음 달 빈 셀 (6줄 채우기)
    final totalCells = cells.length;
    final targetCells = ((totalCells / 7).ceil()) * 7;
    final nextMonth = month == 12 ? 1 : month + 1;
    final nextYear = month == 12 ? year + 1 : year;

    for (var i = 0; i < targetCells - totalCells; i++) {
      final day = i + 1;
      final date = DateTime(nextYear, nextMonth, day);
      final dateStr = formatDate(date);
      final weekday = (totalCells + i) % 7;

      cells.add(CalendarDayCell(
        day: day,
        isToday: false,
        isSelected: false,
        isWeekend: weekday == 0,
        isSaturday: weekday == 6,
        isCurrentMonth: false,
        events: eventsMap[dateStr] ?? [],
        onTap: () => onDateSelected(date),
      ));
    }

    return cells;
  }

}
