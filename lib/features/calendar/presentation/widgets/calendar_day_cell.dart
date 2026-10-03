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
    this.isHoliday = false,
    this.events = const [],
    this.hasMemo = false,
  });

  final int day;
  final bool isToday;
  final bool isSelected;
  final bool isWeekend;
  final bool isCurrentMonth;
  final bool isSaturday;

  /// 대한민국 공휴일 — 일요일과 같은 빨강으로 표시(토요일 골드보다 우선).
  final bool isHoliday;
  final VoidCallback onTap;
  final List<CalendarEvent> events;

  /// 그 날 날짜 붙은 포스트잇이 있다 — 일정 점(원)과 모양으로 갈리는 네모 점.
  final bool hasMemo;

  static const memoMarkerKey = Key('calendar_memo_marker');

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // 셀 높이를 명시해 dot 유무에 따라 행 높이가 흔들리지 않게 한다.
        // dayNumber 28 + dot 4 + padding 1 = 33pt → 34pt(1pt 마진).
        // pager의 고정 높이와 같은 상수에서 나온다(AppSizes.calendarGridHeight).
        height: AppSizes.calendarCellHeight,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.calendarSelected : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.radius8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildDayNumber(),
            if (events.isNotEmpty || hasMemo) _buildMarkers(),
          ],
        ),
      ),
    );
  }

  Widget _buildDayNumber() {
    Color textColor;
    if (!isCurrentMonth) {
      textColor = AppColors.textHint.withValues(alpha: 0.4);
    } else if (isHoliday || (isWeekend && !isSaturday)) {
      // 공휴일은 일요일과 같은 빨강 — 토요일과 겹쳐도 빨강 우선
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
          ? BoxDecoration(
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
          fontSize: 14,
          fontWeight: isToday || isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isToday ? AppColors.onGold : textColor,
        ),
      ),
    );
  }

  /// 그 날 마커. 미완료 중요 이벤트가 있으면 색이 아닌 형태(골드 ★)로 강조하고,
  /// 아니면 기존 점(dot)을 그린다. (공휴일 빨강·토요일 골드 색 규칙과 충돌 회피)
  Widget _buildMarkers() {
    final hasImportant = events.any((e) => e.isImportant && !e.isCompleted);
    if (hasImportant) {
      // dot 슬롯(약 5px)과 같은 레이아웃 높이를 보고하되, OverflowBox로 별만
      // 크게 그려 셀 높이(34px)를 넘기지 않게 한다.
      final star = SizedBox(
        height: 5,
        child: OverflowBox(
          minHeight: 0,
          maxHeight: double.infinity,
          child: Icon(
            Icons.star_rounded,
            key: const Key('day_important_star'),
            size: 11,
            color: isCurrentMonth
                ? AppColors.gold
                : AppColors.gold.withValues(alpha: 0.3),
          ),
        ),
      );
      if (!hasMemo) return star;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [star, _buildMemoMarker()],
      );
    }
    return _buildEventDots();
  }

  /// 포스트잇 네모 점. 색은 보조 — 골드는 오늘·중요, 파랑은 이벤트·토요일이 이미 쓴다.
  Widget _buildMemoMarker() {
    return Container(
      key: memoMarkerKey,
      width: 4,
      height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      color: isCurrentMonth
          ? AppColors.sub
          : AppColors.sub.withValues(alpha: 0.3),
    );
  }

  Widget _buildEventDots() {
    final dotCount = events.length > 3 ? 3 : events.length;
    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ...List.generate(dotCount, (index) {
            final event = events[index];
            // 완료된 이벤트는 작고 회색 톤의 점으로 표시해 "지나간 일정" 느낌 전달
            // (색상 피커 제거 후 미완료 점은 공통 액센트로 통일 — 저장된 color 무시)
            final isDone = event.isCompleted;
            final baseColor = isDone
                ? AppColors.textHint
                : AppColors.eventAccent;
            final size = isDone ? 3.0 : 4.0;
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
          if (hasMemo) _buildMemoMarker(),
        ],
      ),
    );
  }
}
