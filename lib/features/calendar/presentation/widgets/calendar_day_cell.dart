import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/calendar_event.dart';

/// 캘린더 그리드의 개별 날짜 셀
class CalendarDayCell extends StatelessWidget {
  const CalendarDayCell({
    super.key,
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.isWeekend,
    required this.isCurrentMonth,
    required this.isSaturday,
    required this.onTap,
    this.events = const [],
  });

  final int day;
  final bool isToday;
  final bool isSelected;
  final bool isWeekend;
  final bool isCurrentMonth;
  final bool isSaturday;
  final VoidCallback onTap;
  final List<CalendarEvent> events;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? AppColors.calendarSelected : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.radius8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildDayNumber(),
            if (events.isNotEmpty) _buildEventDots(),
          ],
        ),
      ),
    );
  }

  Widget _buildDayNumber() {
    Color textColor;
    if (!isCurrentMonth) {
      textColor = AppColors.textHint.withValues(alpha: 0.4);
    } else if (isWeekend && !isSaturday) {
      textColor = AppColors.calendarWeekend;
    } else if (isSaturday) {
      textColor = AppColors.calendarSaturday;
    } else {
      textColor = AppColors.textPrimary;
    }

    return Container(
      width: 28,
      height: 28,
      decoration: isToday
          ? const BoxDecoration(
              color: AppColors.calendarToday,
              shape: BoxShape.circle,
            )
          : null,
      alignment: Alignment.center,
      child: Text(
        '$day',
        style: TextStyle(
          fontSize: 13,
          fontWeight: isToday || isSelected ? FontWeight.w700 : FontWeight.w400,
          color: isToday ? Colors.white : textColor,
        ),
      ),
    );
  }

  Widget _buildEventDots() {
    final dotCount = events.length > 3 ? 3 : events.length;
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.spacing4 / 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(dotCount, (index) {
          return Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: isCurrentMonth
                  ? events[index].eventColor
                  : events[index].eventColor.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }
}
