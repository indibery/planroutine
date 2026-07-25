import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/korean_holidays.dart';
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
    CalendarStrings.weekdaySun,
    CalendarStrings.weekdayMon,
    CalendarStrings.weekdayTue,
    CalendarStrings.weekdayWed,
    CalendarStrings.weekdayThu,
    CalendarStrings.weekdayFri,
    CalendarStrings.weekdaySat,
  ];

  @override
  Widget build(BuildContext context) {
    // 주말 열 배경을 셀이 아니라 그리드 뒤에 한 장으로 깐다. 셀마다 그리면 radius로
    // 열이 끊기고 헤더까지 이어지지 않는다.
    //
    // 바깥 Column(mainAxisSize.min)이 필요한 이유: 부모(CalendarMonthPager)가 6행 기준
    // 고정 높이(230)를 주는데, 5행인 달은 그리드가 더 짧다. Stack이 그 tight 제약을
    // 그대로 받으면 Positioned.fill이 빈 주 자리까지 배경을 칠해 열이 아래로 샌다.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            Positioned.fill(child: _buildWeekendColumns()),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildWeekdayHeader(),
                const SizedBox(height: AppSizes.spacing4),
                _buildDayGrid(),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// 토·일 열 배경 — 요일 헤더부터 마지막 주까지 세로로 이어져 요일이 '열'로 읽힌다.
  /// 헤더/그리드와 같은 7분할이라 열이 정확히 맞는다.
  Widget _buildWeekendColumns() {
    return Row(
      key: const Key('calendar_weekend_columns'),
      children: List.generate(7, (index) {
        final isSunday = index == 0;
        final isSaturday = index == 6;
        if (!isSunday && !isSaturday) {
          return const Expanded(child: SizedBox.shrink());
        }
        return Expanded(
          child: DecoratedBox(
            key: Key(isSunday ? 'weekend_column_sun' : 'weekend_column_sat'),
            decoration: BoxDecoration(
              color: isSunday
                  ? AppColors.calendarWeekendTint
                  : AppColors.calendarSaturdayTint,
              // 바깥쪽 모서리만 둥글려 화면 가장자리에서 띠처럼 마감된다.
              borderRadius: BorderRadius.horizontal(
                left: isSunday
                    ? const Radius.circular(AppSizes.radius8)
                    : Radius.zero,
                right: isSaturday
                    ? const Radius.circular(AppSizes.radius8)
                    : Radius.zero,
              ),
            ),
            child: const SizedBox.expand(),
          ),
        );
      }),
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
          // 평일은 본문색 — 라벨(요일)이 데이터(날짜)보다 옅으면 배경처럼 묻힌다.
          textColor = AppColors.textPrimary;
        }
        return Expanded(
          child: Center(
            child: Text(
              _weekdays[index],
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                fontWeight: FontWeight.w700,
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
        isHoliday: isKoreanHoliday(date),
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
        isHoliday: isKoreanHoliday(date),
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
        isHoliday: isKoreanHoliday(date),
        isCurrentMonth: false,
        events: eventsMap[dateStr] ?? [],
        onTap: () => onDateSelected(date),
      ));
    }

    return cells;
  }

}
