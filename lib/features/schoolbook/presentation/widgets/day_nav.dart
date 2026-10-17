import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// `10월 20일 (화)`
String dayLabel(DateTime day) => '${day.month}월 ${day.day}일 (${_weekdays[day.weekday - 1]})';

/// ◀ 날짜 ▶ — 평일만 하루씩. 넘길 수 없으면 콜백이 null이다.
class DayNav extends StatelessWidget {
  const DayNav({super.key, required this.day, this.onPrevious, this.onNext});

  final DateTime day;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  static const previousKey = Key('schoolbook_previous_day');
  static const nextKey = Key('schoolbook_next_day');

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          key: previousKey,
          onPressed: onPrevious,
          color: AppColors.gold,
          icon: const Icon(Icons.chevron_left, semanticLabel: SchoolbookStrings.previousDay),
        ),
        Expanded(
          child: Text(
            dayLabel(day),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
        ),
        IconButton(
          key: nextKey,
          onPressed: onNext,
          color: AppColors.gold,
          icon: const Icon(Icons.chevron_right, semanticLabel: SchoolbookStrings.nextDay),
        ),
      ],
    );
  }
}
