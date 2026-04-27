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
        // 셀 높이를 명시해 dot 유무에 따라 행 높이가 흔들리지 않게 한다.
        // (dayNumber 28 + dot 5 + padding 약간) → 36pt면 dot 있어도 안 잘리고
        // dot 없을 때도 동일한 행 높이를 유지.
        height: 36,
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
          : isSelected
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold, width: 1),
                )
              : null,
      alignment: Alignment.center,
      child: Text(
        '$day',
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 13,
          fontWeight: isToday || isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isToday ? AppColors.navy : textColor,
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
          final event = events[index];
          // 완료된 이벤트는 작고 회색 톤의 점으로 표시해 "지나간 일정" 느낌 전달
          final isDone = event.isCompleted;
          final baseColor = isDone ? AppColors.textHint : event.eventColor;
          final size = isDone ? 4.0 : 5.0;
          return Container(
            width: size,
            height: size,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: isCurrentMonth
                  ? baseColor
                  : baseColor.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }
}
