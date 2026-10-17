import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/button_semantics.dart';
import '../../domain/booking_dates.dart';

/// 이번 주 월~금 날짜 띠(시안 A). 양 끝 ◀ ▶로 지난주·다음 주.
/// 예약 가능 범위를 넘는 날은 누를 수 없고, 지난 날은 조회만 한다.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.day,
    required this.today,
    required this.onSelect,
    required this.onPreviousWeek,
    this.onNextWeek,
  });

  final DateTime day;
  final DateTime today;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onPreviousWeek;

  /// 다음 주가 예약 가능 범위 밖이면 null.
  final VoidCallback? onNextWeek;

  static const previousWeekKey = Key('schoolbook_previous_week');
  static const nextWeekKey = Key('schoolbook_next_week');
  static Key dayKey(DateTime d) => Key('schoolbook_day_${d.year}-${d.month}-${d.day}');

  @override
  Widget build(BuildContext context) {
    final last = lastBookableDate(today);
    final todayOnly = DateTime(today.year, today.month, today.day);
    return Row(
      children: [
        IconButton(
          key: previousWeekKey,
          onPressed: onPreviousWeek,
          color: AppColors.gold,
          icon: const Icon(Icons.chevron_left, semanticLabel: SchoolbookStrings.previousWeek),
        ),
        for (final d in weekOf(day))
          Expanded(
            child: _DayCell(
              key: dayKey(d),
              day: d,
              selected: d == DateTime(day.year, day.month, day.day),
              isToday: d == todayOnly,
              onTap: d.isAfter(last) ? null : () => onSelect(d),
            ),
          ),
        IconButton(
          key: nextWeekKey,
          onPressed: onNextWeek,
          color: AppColors.gold,
          icon: const Icon(Icons.chevron_right, semanticLabel: SchoolbookStrings.nextWeek),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    super.key,
    required this.day,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool isToday;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = onTap == null
        ? AppColors.faint
        : selected
            ? AppColors.gold
            : AppColors.ink;
    return ButtonSemantics.gesture(
      label: SchoolbookStrings.dayLabel(day),
      selected: selected,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing8),
        decoration: BoxDecoration(
          color: selected ? AppColors.goldFill.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.radius12),
          border: Border.all(
            color: isToday && !selected ? AppColors.line : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              SchoolbookStrings.weekdayName(day),
              style: TextStyle(fontSize: 12, color: selected ? AppColors.gold : AppColors.sub),
            ),
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
